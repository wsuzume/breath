# retriever
System configuration manager written in Python3.6.

`retriever` is a single-file pure perl5 program so can be used without poluting environment.

## Install
```make install```

## Usage
`retriever` is a simple template engine. Just write your configuration file as below: example `docker-compose.yml` as `docker-compose.rtvr`.

```
version "3"

services:
  container1:
    image: nginx:latest
    volumes:
      - {{{ROOT_DIRECTORY}}}
      - {{{CERT_FILES_DIRECTORY}}}
    port:
      - {{{PORT}}}
```

When you execute `retriever read`, it produces `retriever.yml` from all `*.rtvr` files in your current working directory as below.

```
./docker-compose.rtvr:
  extension:
  env_vars:
    ROOT_DIRECTORY:
    CERT_FILES_DIRECTORY:
    PORT:

./other/breath_file.trvr:
  extension:
  env_vars:
    AAA:
    BBB:

```

Then, write configuration.

```
./docker-compose.rtvr:
  extension: .yml
  env_vars:
    ROOT_DIRECTORY: ./nginx/html:/usr/share/nginx/html
    CERT_FILES_DIRECTORY: ./certs:/pki/tls
    PORT: "80:80"

./other/breath_file.rtvr:
  extension:
  env_vars:
    AAA:
    BBB:

```

And just execute `retriever write` will replace all variables.

### Note
You can't use `:` in variable's name.

Blank variable is prohibitted. You should set all variables to run `retriever write`.

`retriever` replaces each `*.rtvr` file's extension with the extension you write in `extension:`. For example, `extension: .yml` for `docker-compose.rtvr` results in `docker-compose.yml`.

If you forget `.`, it's OK. For example, `extension: yml` for `docker-compose.rtvr` also results in `docker-compose.yml`. And if you don't need any extension, just delete `extension:` like below.

```
./other/breath_file.rtvr:
  env_vars:
    AAA:
    BBB:

```

It will produce `./other/breath_file`.
