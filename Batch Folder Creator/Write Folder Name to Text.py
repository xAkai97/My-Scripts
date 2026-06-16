import os

def write_folder_names_to_txt(directory, output_file):
    with open(output_file, 'w') as f:
        for item in os.listdir(directory):
            if os.path.isdir(os.path.join(directory, item)):
                f.write(item + '\n')

# Set directory_path to current directory
directory_path = os.getcwd()
output_file_path = 'folder_names.txt'

write_folder_names_to_txt(directory_path, output_file_path)
