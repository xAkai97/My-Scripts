import json
import os

def create_rule(rule_name, rule_pattern, save_path):
    rule = {
        rule_name: {
            "addPaused": None,
            "affectedFeeds": [
                "https://subsplease.org/rss/?r=1080"
            ],
            "assignedCategory": "",
            "enabled": True,
            "episodeFilter": "",
            "ignoreDays": 0,
            "lastMatch": "",
            "mustContain": rule_pattern,
            "mustNotContain": "",
            "previouslyMatchedEpisodes": [],
            "priority": 0,
            "savePath": save_path.replace("/", "\\"),  # Use backslashes for savePath
            "smartFilter": False,
            "torrentContentLayout": None,
            "torrentParams": {
                "category": "",
                "download_limit": -1,
                "download_path": "",
                "inactive_seeding_time_limit": -2,
                "operating_mode": "AutoManaged",
                "ratio_limit": -2,
                "save_path": save_path.replace("\\", "/"),  # Use forward slashes for torrentParams save_path
                "seeding_time_limit": -2,
                "skip_checking": False,
                "tags": [],
                "upload_limit": -1,
                "use_auto_tmm": False
            },
            "useRegex": False
        }
    }
    return rule

def read_rules_from_file(file_name, rule_prefix, year):
    rules = []
    file_path = os.path.join(os.getcwd(), file_name)
    save_path_prefix = f"disk4/Anime/Web/{rule_prefix} {year}/"
    with open(file_path, 'r') as file:
        for line in file:
            folder_name = line.strip()
            rule_name = f"{rule_prefix} - {folder_name}"
            save_path = os.path.join(save_path_prefix, folder_name)
            rules.append(create_rule(rule_name, folder_name, save_path))
    return rules

def choose_season_prefix():
    seasons = ["Spring", "Summer", "Fall", "Winter"]
    while True:
        print("Available seasons:")
        for i, season in enumerate(seasons, start=1):
            print(f"{i}. {season}")
        choice = input("Choose a season (enter the corresponding number): ")
        if choice.isdigit() and 1 <= int(choice) <= len(seasons):
            return seasons[int(choice) - 1]
        else:
            print("Invalid choice. Please enter a number between 1 and", len(seasons))

def main():
    # Change the file name to 'folder_names.txt'
    input_file = 'folder_names.txt'
    rule_prefix = choose_season_prefix()
    year = input("Enter Anime Year: ")
    rules = read_rules_from_file(input_file, rule_prefix, year)

    # Write rules to JSON file without extra curly braces and comma
    with open('qbittorrent_rules.json', 'w') as f:
        json.dump({rule_name: rule_data for rule in rules for rule_name, rule_data in rule.items()}, f, indent=4)

if __name__ == "__main__":
    main()
