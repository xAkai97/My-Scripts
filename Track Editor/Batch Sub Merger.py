import os
import subprocess
from pathlib import Path

MKVMERGE_PATH = Path(r"C:/Users/Akai/Downloads/Video & Audio/mkvtoolnix-64/mkvtoolnix/mkvmerge.exe")
OUTPUT_FOLDER = Path("Remux")


def main():
    print("Batch Sub Merger")

    extension = input("Main Extension (MKS, ASS)? : ").lower()
    if extension not in ["mks", "ass"]:
        print("Invalid input. Exiting.")
        return

    remove_sub = input("Remove Existing Subtitles [y/n]? : ").lower()
    rem_sub = "--no-subtitles" if remove_sub == "y" else ""

    merge_type = input("Merge ASS, MKS, or XML? : ").lower()
    if merge_type not in ["ass", "mks", "xml"]:
        print("Invalid input. Exiting.")
        return

    sec_extension = merge_type

    if not MKVMERGE_PATH.exists():
        print("Error: mkvmerge.exe not found at the specified path.")
        return

    if not OUTPUT_FOLDER.exists():
        OUTPUT_FOLDER.mkdir(parents=True)

    for filename in os.listdir("."):
        if filename.endswith(f".{extension}"):
            output_file = OUTPUT_FOLDER / filename
            cmd = [str(MKVMERGE_PATH), "-o", str(output_file), str(filename), "--default-track", "0:yes"]
            if rem_sub:
                cmd.insert(3, rem_sub)
            if sec_extension == "ass":
                cmd += ["--language", "0:en", str(filename), "--chapter-language", "en"]
            elif sec_extension == "xml":
                xml_filename = os.path.splitext(filename)[0] + ".xml"
                if not os.path.exists(xml_filename):
                    print(f"Error: Could not find '{xml_filename}' for reading.")
                    continue
                cmd += ["--language", "0:en", str(filename), "--chapter-language", "en", "--chapters", str(xml_filename)]
            elif sec_extension == "mks" and rem_sub != "--no-subtitles":
                cmd += ["--no-subtitles"]
            subprocess.run(cmd)

    print("Finished operation!")


if __name__ == "__main__":
    main()
