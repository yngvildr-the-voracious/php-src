#!/bin/bash
# Made entirely with Claude (Anthropic's Claude Opus 5.5, in Claude Code).
# Build one PHP tree as Apache mod_php + CLI + CGI, inside the dak-c7 container.
# Usage: build.sh <tree>     (tree = directory name under /dak/work)
# Same configure line for every tree so results are comparable.
set -euo pipefail
t=$1
cd /dak/work/$t

./configure --prefix=/dak/inst/$t \
  --with-config-file-path=/dak/inst/$t/etc \
  --with-apxs2=/usr/bin/apxs \
  --with-openssl --with-zlib --with-curl \
  --enable-mbstring --disable-mbregex \
  --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd \
  > /dak/logs/$t.configure.log 2>&1

make -j"${JOBS:-8}" > /dak/logs/$t.make.log 2>&1
# apxs -i also copies libphp7.so into the (throwaway) container's httpd modules dir.
make install > /dak/logs/$t.install.log 2>&1

/dak/inst/$t/bin/php -v
/dak/inst/$t/bin/php-config --extension-dir
