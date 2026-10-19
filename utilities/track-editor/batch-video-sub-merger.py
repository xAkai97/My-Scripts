import os
import subprocess
from pathlib import Path

MKVMERGE_PATH = Path(r"C:/Users/Akai/Downloads/Video & Audio/mkvtoolnix-64/mkvtoolnix/mkvmerge.exe")
OUTPUT_FOLDER = Path("Remux")

def main():
    print("Batch Video Sub Merger")

    extension = "mkv"

    remove_sub = input("Remove Existing Subtitles [y/n]? : ").lower()
    rem_sub = "--no-subtitles" if remove_sub == "y" else ""

    merge_type = input("Merge ASS, MKS: ").lower()
    if merge_type not in ["ass", "mks"]:
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
            cmd = [str(MKVMERGE_PATH), "-o", str(output_file), str(filename)]
            if rem_sub:
                cmd.append(rem_sub)
            
            # Add secondary file if it exists
            secondary_file = Path(filename).with_suffix(f".{sec_extension}")
            if not secondary_file.exists():
                print(f"Warning: Could not find '{secondary_file}' for merging. Skipping file.")
                continue

            cmd += ["--track-order", "0:0,1:0", str(secondary_file)]

            subprocess.run(cmd, check=True)

    print("Finished operation!")

if __name__ == "__main__":
    main()
