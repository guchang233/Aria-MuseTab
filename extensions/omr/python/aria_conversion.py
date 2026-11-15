# SPDX-License-Identifier: AGPL-3.0-only
"""Headless entry points shared by Android's private worker and desktop checks."""
from copy import deepcopy
import hashlib
import json
import os
from pathlib import Path
import xml.etree.ElementTree as ET


def validate_models(models):
    models = Path(models)
    inventory = json.loads((models / "verified.json").read_text(encoding="utf-8"))
    expected = {
        "segnet_308_int8.tflite": "a7caace11bcd3df8aaa6addfa89eb994a8bdade34f977430742e8565e7f0acb7",
        "encoder_414_int8.tflite": "42f98864b83caa25e8da59bbfdf0f864d1860c3c13ac2a62e1e9e9fdaaba0a2c",
        "decoder_414_int8.onnx": "694a48cae3bc5cbf4f179c70833bd0a58233fe1adf53fe0154b6b6377542f957",
    }
    if {m["file"]: m["sha256"] for m in inventory["models"]} != expected:
        raise ValueError("识别模型清单不正确，请重新安装模型")
    for name, digest in expected.items():
        actual = hashlib.sha256()
        with (models / name).open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""): actual.update(chunk)
        if actual.hexdigest() != digest:
            raise ValueError("识别模型校验失败：" + name)


def recognize_page(image, output, models, status, cancel, page=1, total=1):
    os.environ.update(ARIA_OMR_MODELS=str(models), ARIA_OMR_STATUS=str(status), ARIA_OMR_CANCEL=str(cancel),
                      ARIA_OMR_PAGE=str(page), ARIA_OMR_TOTAL=str(total), TF_CPP_MIN_LOG_LEVEL="2")
    import aria_omr_runtime as runtime
    runtime.MODEL_STORAGE = str(models)
    runtime.check_cancelled()
    runtime.appdata.homr_progress = 0
    runtime.appdata.homr_state = "Preparing"
    from homr.main import process_image, ProcessingConfig
    from homr.music_xml_generator import XmlGeneratorArguments
    from homr.segmentation.inference_segnet import cleanup_segnet
    from homr.transformer.tromr import cleanup_tromr
    try:
        process_image(str(image), ProcessingConfig(False, False, False, False, -1, False),
                      XmlGeneratorArguments(), str(output))
        runtime.check_cancelled()
        root = ET.parse(output).getroot()
        if root.tag != "score-partwise" or not any(n.find("pitch") is not None for n in root.iter("note")):
            raise ValueError("未识别出可播放音符，请检查页面清晰度或换一页重试")
        return str(output)
    finally:
        cleanup_segnet()
        cleanup_tromr()


def merge_pages(paths, destination):
    """Join only matching instrumentation. Keep separate page results when ambiguous."""
    roots = [ET.parse(p).getroot() for p in paths]
    if not roots:
        raise ValueError("没有识别结果")
    def signature(root):
        names = [p.findtext("part-name", "").strip() for p in root.findall("part-list/score-part")]
        staves = [p.findtext("measure/attributes/staves", "1") for p in root.findall("part")]
        return names, staves
    if any(signature(root) != signature(roots[0]) for root in roots[1:]):
        return {"outputs": [str(p) for p in paths], "warning": "各页的乐器或谱表结构不同，已分别保留，需校对后合并。"}
    result = deepcopy(roots[0])
    parts = result.findall("part")
    for root in roots[1:]:
        for target, incoming in zip(parts, root.findall("part"), strict=True):
            for index, measure in enumerate(incoming.findall("measure")):
                measure = deepcopy(measure)
                if index == 0:
                    mark = measure.find("print")
                    if mark is None:
                        mark = ET.Element("print")
                        measure.insert(0, mark)
                    mark.set("new-page", "yes")
                target.append(measure)
    for part in parts:
        for number, measure in enumerate(part.findall("measure"), 1):
            measure.set("number", str(number))
    ET.indent(result)
    ET.ElementTree(result).write(destination, encoding="utf-8", xml_declaration=True)
    return {"outputs": [str(destination)], "warning": "识别结果需要校对音高、节奏、声部和反复记号。"}


def finish(paths_json, destination):
    return json.dumps(merge_pages(json.loads(paths_json), destination), ensure_ascii=False)
