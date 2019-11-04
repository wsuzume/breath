
import argparse
from jinja2 import Environment, FileSystemLoader, select_autoescape, meta
from jinja2.exceptions import TemplateNotFound
import os
import pathlib
import sys
import yaml

CONFIG_DIR_NAME = '.retriever_config'

class ManagedDirectory:
    def __init__(self, path):
        self.path = path
        self.files = []

def get_accessible_upstream(abspath):
    upstream = []
    while os.access(abspath, os.F_OK | os.R_OK | os.W_OK):
        upstream.append(abspath)
        abspath = os.path.split(abspath)[0]
    return upstream

def first_appears_in(xs, filename, f=None):
    if f is None:
        f = os.path.isdir
    for x in xs:
        path = os.path.join(x, filename)
        if f(path):
            return (x, filename)
    return None

def split_all_exts(path):
    root, ext = os.path.splitext(path)
    exts = []
    while ext != '':
        exts.append(ext)
        root, ext = os.path.splitext(root)
    return exts

def is_retriever_file(path, ext='.rtvr'):
    return ext in split_all_exts(path)

def get_retriever_targets(root_path):
    root_dir = ManagedDirectory(root_path)
    cur_managed_dir = [root_dir]
    stack = []
    for root, directory, files in os.walk(root_dir.path):
        #print(root, directory, files)
        if os.path.commonprefix([root, cur_managed_dir[0].path]) != cur_managed_dir[0].path:
            #print('here', root, cur_managed_dir[0], os.path.commonprefix([root, cur_managed_dir[0]]))
            stack.append(cur_managed_dir.pop(0))
        if CONFIG_DIR_NAME in directory and root != cur_managed_dir[0].path:
            cur_managed_dir.insert(0, ManagedDirectory(root))
        for filename in list(filter(is_retriever_file, files)):
            cur_managed_dir[0].files.append(os.path.join(root, filename))
    return sorted(stack + cur_managed_dir, key=lambda x: x.path)

def yes_no_input(msg):
    print(msg + ' [y/N]: ', end='')
    res = input().strip()
    if res == 'y' or res == 'yes':
        return True
    return False

# one file
class Game:
    def __init__(self):
        self.path = None
        self.extension = None
        self.contents = None

class Retriever:
    def __init__(self, args):
        self.args = args

    def get_env(self, path):
        return Environment(
                    variable_start_string='{{{',
                    variable_end_string='}}}',
                    loader=FileSystemLoader(
                            searchpath=path,
                            encoding='utf-8',
                            followlinks=False
                            ),
                    autoescape=select_autoescape(
                                enabled_extensions=(),
                                disabled_extensions=()
                                )
                    )


    def get_config_location(self, abspath):
        upstream = get_accessible_upstream(abspath)
        return first_appears_in(upstream, CONFIG_DIR_NAME, f=os.path.isdir)

    def check_config(self, loc, abspath):
        if loc is None:
            pass
        elif loc[0] == abspath:
            print('Error: This directory is already initialized.')
            print('Aborted.')
            sys.exit(1)
        else:
            print('Warning: This directory is already managed under \'' + os.path.join(loc[0], loc[1]) + '\'.')
            if not yes_no_input('Continue anyway?'):
                print('Aborted.')
                sys.exit(1)

    def init(self):
        abspath = os.path.abspath(os.getcwd())

        loc = self.get_config_location(abspath)
        self.check_config(loc, abspath)

        config_path = os.path.join(abspath, CONFIG_DIR_NAME)

        try:
            os.mkdir(config_path)
        except FileExistsError:
            print('Error: This directory is already initialized.')
            print('Aborted.')
            sys.exit(1)

        with open(os.path.join(config_path, 'config.yml'), 'w') as f:
            f.write(yaml.dump(
                { 'extension': 'rtvr',
                  'source': self.args.source,
                  'destination': self.args.dest,
                  'name': self.args.name,
                }, default_flow_style=False))

    def read(self):
        abspath = os.path.abspath(os.getcwd())

        loc = self.get_config_location(abspath)
        os.chdir(loc[0])
        print('Running on \'' + loc[0] + '\'')
        cwd = os.path.abspath(os.getcwd())
        self.env = self.get_env(cwd)
        p_cwd = pathlib.Path(cwd)

        targets = get_retriever_targets(cwd)

        target_dict = {}
        for target in targets:
            buf = {}
            for f in target.files:
                try:
                    p_f = pathlib.Path(f)
                    source = self.env.loader.get_source(self.env, str(p_f.relative_to(p_cwd)))
                    parsed_content = self.env.parse(source)
                    variables = meta.find_undeclared_variables(parsed_content)
                    keys = {}
                    for key in variables:
                        keys[key] = None
                    buf[f] = keys
                except TemplateNotFound:
                    pass
            target_dict[target.path] = buf
        print(yaml.dump(target_dict, default_flow_style=False))



    def write(self):
        pass

    def save(self):
        pass

def retriever_init(args):
    retriever = Retriever(args)
    retriever.init()

def retriever_read(args):
    retriever = Retriever(args)
    retriever.read()

def retriever_write(args):
    retriever = Retriever(args)
    retriever.write()

def retriever_save(args):
    retriever = Retriever(args)
    retriever.save()

def retriever_main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest='mode', help='sub-command help')

    parser_init = subparsers.add_parser('init', help='init help')
    parser_init.add_argument('source', nargs='?', default='.', help='read source path')
    parser_init.add_argument('dest', nargs='?', default='./retriever_backup', help='save destination path')
    parser_init.add_argument('name', nargs='?', default='./retriever.yml', help='read source path')
    parser_init.add_argument('-f', action='store_true', help='execute without confirmation')
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
