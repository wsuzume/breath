
import argparse
import jinja2
import os
import sys
import yaml

# one file
class Game:
    def __init__(self):
        self.path = None
        self.extension = None
        self.contents = None

class Retriever:
    def __init__(self):
        pass

    def read_config():
        pass


def retriever_init(args):
    pass

def retriever_read(args):
    with os.scandir('../test') as target:
        for entry in target:
            print(entry.path)

def retriever_write(args):
    pass

def retriever_save(args):
    pass

def retriever_main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest='mode', help='sub-command help')

    parser_init = subparsers.add_parser('init', help='init help')
    parser_init.add_argument('source', nargs='?', default='.', help='read source path')
    parser_init.add_argument('dest', nargs='?', default='./retriever_backup', help='save destination path')
    parser_init.add_argument('name', nargs='?', default='./retriever.yml', help='read source path')
    parser_init.set_defaults(func=retriever_init)

    parser_read = subparsers.add_parser('read', help='read help')
    parser_read.add_argument('-f', action='store_true',
                            help='execute without confirmation and overwrite current environment')
    parser_read.add_argument('--inherit', action='store_false', help='inherit current environment')
    parser_read.set_defaults(func=retriever_read)

    parser_write = subparsers.add_parser('write', help='write help')
    parser_write.add_argument('-f', action='store_true', help='execute without confirmation')
    parser_write.set_defaults(func=retriever_write)

    parser_save = subparsers.add_parser('save', help='save help')
    parser_save.add_argument('dest', nargs='?', default=None, help='save destination path')
    parser_save.set_defaults(func=retriever_save)

    args = parser.parse_args()
    args.func(args)

if __name__ == "__main__":
    retriever_main()
