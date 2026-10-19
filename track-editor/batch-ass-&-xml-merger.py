import os
import subprocess
from pathlib import Path

MKVMERGE_PATH = Path("C:/Users/Akai/Downloads/Video & Audio/mkvtoolnix-64/mkvtoolnix/mkvmerge.exe")
OUTPUT_FOLDER = Path("Remux")


def main():
    print("Batch Sub Merger")

    extension = "ass"
    merge_type = "xml"

    if not MKVMERGE_PATH.exists():
        print("Error: mkvmerge.exe not found at the specified path.")
        return

    if not OUTPUT_FOLDER.exists():
        OUTPUT_FOLDER.mkdir(parents=True)

    subtitle_files = [filename for filename in os.listdir(".") if filename.endswith(f".{extension}")]
    
    for filename in subtitle_files:
        output_file = OUTPUT_FOLDER / (Path(filename).stem + ".mks")
        cmd = [MKVMERGE_PATH, "-o", output_file, filename, "--default-track", "0:yes"]
        if merge_type == "xml":
            xml_filename = Path(filename).with_suffix(".xml")
            if not xml_filename.exists():
                print(f"Error: Could not find '{xml_filename}' for reading.")
                continue
            cmd += ["--language", "0:en", filename, "--chapter-language", "en", "--chapters", str(xml_filename)]
        subprocess.run(cmd)

    print("Finished operation!")


if __name__ == "__main__":
    main()
