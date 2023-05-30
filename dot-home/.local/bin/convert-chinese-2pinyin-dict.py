#!/usr/bin/env python3

import sys
from pypinyin import pinyin, Style

def convert_print_dict(file_path, default_freq):
    """TODO: Docstring for convert_print_dict.

    :file_path: TODO
    :returns: TODO

    """
    with open(file_path, 'r') as f:
        for word in f.readlines():
            strip_word=word.strip()
            pinyin_list = pinyin(strip_word, style=Style.NORMAL)
            print("%s %s %d"%(strip_word, "'".join([ x[0] for x in pinyin_list ]), default_freq))

def main():
    """TODO: Docstring for main.
    :returns: TODO

    """
    if 2 > len(sys.argv):
        print("""
Convert customized dictory to libime dict.
Raw dict format: words pinyin freq.
Usage: 
    sh convert-chinese-2pinyin-dict.py input_file_in_raw_dict
""")


        sys.exit(1)


    freq = 0
    if 2 < len(sys.argv):
        freq = int(sys.argv[2])
    convert_print_dict(sys.argv[1], freq)
    

if __name__ == "__main__":
    main()
