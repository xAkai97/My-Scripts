from pathlib import Path
import sys
import subprocess

MKVMERGE_PATH = Path(r"C:/Users/Akai/Downloads/Video & Audio/mkvtoolnix-64/mkvtoolnix/mkvmerge.exe")
OUTPUT_FOLDER = Path("Remux")

def main():
    print("MKV Track Remover")

    if not OUTPUT_FOLDER.exists():
        OUTPUT_FOLDER.mkdir()

    print_menu()
    tracks = input("Choose Tracks To Remove (comma-separated): ").split(',')

    if '0' in tracks:
        sys.exit()

    valid_tracks = {'1', '2', '3', '4', '5', '6'}
    if not set(tracks).issubset(valid_tracks):
        print("Invalid option(s) selected.")
        main()
        return

    if '6' in tracks:
        mks_mode()
    else:
        remove_tracks(tracks)

def print_menu():
    print("Choose what to Remove (you can select multiple options separated by commas):")
    print("    0. Exit")
    print("    1. Video")
    print("    2. Audio")
    print("    3. Subtitles")
    print("    4. Attachments")
    print("    5. Chapters")
    print("    6. MKS Sub Removal Mode")

def remove_tracks(tracks):
    options = {
        "1": "--no-video",
        "2": "--no-audio",
        "3": "--no-subtitles",
        "4": "--no-attachments",
        "5": "--no-chapters"
    }

    track_options = [options[track] for track in tracks if track in options]

    output_extension = determine_output_extension(tracks)

    for file in Path(".").glob("*.mkv"):
        output_file = OUTPUT_FOLDER / (file.stem + "_remux." + output_extension)
        subprocess.run([MKVMERGE_PATH, "-o", str(output_file)] + track_options + [str(file)])

    print("Finished operation!")

def determine_output_extension(track_set):
    track_set = set(track_set)
    if {'1', '2', '3'}.issubset(track_set):
        return 'mks'
    elif {'1', '2'}.issubset(track_set):
        return 'mka'
    elif {'1', '3'}.issubset(track_set):
        return 'mka'
    elif {'2', '3'}.issubset(track_set):
        return 'mkv'
    elif '1' in track_set:
        return 'mka'
    elif '2' in track_set:
        return 'mkv'
    elif '3' in track_set:
        return 'mkv'
    return 'mkv'

def mks_mode():
    for file in Path(".").glob("*.mks"):
        output_file = OUTPUT_FOLDER / file.name
        subprocess.run([MKVMERGE_PATH, "-o", str(output_file), "--no-subtitles", str(file)])

    print("Finished operation!")

if __name__ == "__main__":
    main()
