import os

# Supported video file extensions
VIDEO_EXTENSIONS = [
    "webm", "mka", "mkv", "mks", "flv", "vob", "ogv", "ogg", "drc", "gif",
    "gifv", "mng", "avi", "mov", "qt", "wmv", "yuv", "rm", "rmvb", "asf",
    "mp4", "m4p", "m4v", "mpg", "mp2", "mpeg", "mpe", "mpv", "mpg", "mpeg",
    "m2v", "m4v", "svi", "3gp", "3g2", "mxf", "roq", "nsv", "flv", "f4v",
    "f4p", "f4a", "f4b"
]

# Supported subtitle file extensions
SUBTITLE_EXTENSIONS = [
    "aqt", "gsub", "txt", "jss", "sub", "ttxt", "pjs", "psb", "rt", "smi",
    "stl", "ssf", "srt", "ssa", "ass", "usf", "idx", "usf", "pgs"
]

# ISO language codes
LANGUAGE_CODES = {
    "eng": "English",
    "jpn": "Japanese",
    # Add more ISO language codes and names here
}

def get_file_extension(valid_extensions, message):
    while True:
        file_extension = input(message).lower()
        if file_extension in valid_extensions:
            print(f"You have chosen {file_extension} as your file format")
            return file_extension
        else:
            print("You have entered something invalid")

def get_iso_language():
    while True:
        iso_language = input("Enter subtitle language (e.g. eng, fre, ger or similar): ")
        language = LANGUAGE_CODES.get(iso_language.lower())
        if language:
            print(f"You have chosen {language} subtitles")
            return iso_language
        else:
            print("You have entered something invalid")

def get_yes_no_input(message):
    while True:
        user_input = input(message).lower()
        if user_input == "y":
            return True
        elif user_input == "n":
            return False
        else:
            print("You have entered something invalid")

def main():
    print("Video & Subtitle Merger")

    video_extension = get_file_extension(VIDEO_EXTENSIONS, "Enter the video file type extension (e.g. mp4): ")
    subtitle_extension = get_file_extension(SUBTITLE_EXTENSIONS, "Enter the subtitle file type extension (e.g. srt): ")
    iso_language = get_iso_language()
    default_subtitle = get_yes_no_input("Do you want to make subtitles default [y/n]? ")
    forced_subtitle = get_yes_no_input("Do you want to make subtitles forced [y/n]? ")
    set_subtitle_track_name = get_yes_no_input("Set Subtitle Track Name [y/n]? ")
    if set_subtitle_track_name:
        subtitle_track_name = input("Subtitle Track Name? ")
    else:
        subtitle_track_name = ""

    # Further steps for muxing operation can be added here

if __name__ == "__main__":
    main()
