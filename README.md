# breath
System configuration manager written in pure perl5.

`breath` is a single-file pure perl5 program so can be used without poluting environment.

## Install
```make install```

## Usage
`breath` is a simple template engine. Just write your configuration file as below: example `docker-compose.yml` as `docker-compose.breath`.

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

When you execute `breath read`, it produces `breath.yml` from all `*.breath` files in your current working directory as below.

```
./docker-compose.breath:
  extension:
  env_vars:
    ROOT_DIRECTORY:
    CERT_FILES_DIRECTORY:
    PORT:

./other/breath_file.breath:
  extension:
  env_vars:
    AAA:
    BBB:

```

Then, write configuration.

```
./docker-compose.breath:
  extension: .yml
  env_vars:
    ROOT_DIRECTORY: ./nginx/html:/usr/share/nginx/html
    CERT_FILES_DIRECTORY: ./certs:/pki/tls
    PORT: "80:80"

./other/breath_file.breath:
  extension:
  env_vars:
    AAA:
    BBB:

```

And just execute `breath write` will replace all variables.

### Note
You can't use `:` in variable's name.

Blank variable is prohibitted. You should set all variables to run `breath write`.

`breath` replaces each `*.breath` file's extension with the extension you write in `extension:`. For example, `extension: .yml` for `docker-compose.breath` results in `docker-compose.yml`.

If you forget `.`, it's OK. For example, `extension: yml` for `docker-compose.breath` also results in `docker-compose.yml`. And if you don't need any extension, just delete `extension:` like below.

```
./other/breath_file.breath:
  env_vars:
    AAA:
    BBB:

```

It will produce `./other/breath_file`.
