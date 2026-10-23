# PHP2Shell backport for PHP 7.4.21

> **Made entirely with Claude.** This backport, its test harness, the test runs and this report were produced by Claude (Anthropic's Claude Opus 5.5, in Claude Code) at the repository owner's request. No human wrote or edited the code or the text. The security fix it carries is the PHP security team's own commit, credited below.

Backport of the PHP security team's end-of-life mitigation for
**CVE-2026-109618 / CVE-2026-109619 ("PHP2Shell")** to the **PHP 7.4.21** release,
tested on a legacy production stack: `Apache/2.4.6 (CentOS) PHP/7.4.21`,
with PHP running as Apache mod_php on CentOS 7.

On this branch the fix is also applied as source changes on top of the official
`php-7.4.21` tag, so `git diff php-7.4.21 -- Zend main ext` shows exactly what it changes.

Tested 2026-10-23. This is not an official PHP release: the PHP project does not
accept patches for end-of-life branches. Its value is that it is the PHP security
team's own fix, adapted mechanically to 7.4.21, with the evidence below.

## Summary

| Question | Answer |
|---|---|
| Applies to the official `php-7.4.21.tar.xz`? | Yes, with `patch -p1`, no fuzz. |
| Behaves like upstream's fix? | Yes. Identical results to 7.4.33 + upstream commit in every check below. |
| Regressions in PHP's own test suite? | None beyond the 9 tests upstream's fix also changes (explained below). |
| Existing compiled extensions must be rebuilt? | **No.** ABI identifiers unchanged, no exported symbol removed, no struct changed. APCu built against *unpatched* 7.4.21 loads and passes its tests on the patched build. |
| Includes the fixes from 7.4.22 to 7.4.33? | **No.** See [Limits](#limits). |

## Files

| File | What it is |
|---|---|
| `php-7.4.21-CVE-2026-109618-109619.patch` | The backport. 18 files, +263/−52. SHA-256 `c678e39adb4ea1c8309706f2af40480eb8661ba6baa0cbc24af451941af9ead2` |
| `upstream-PHP-7.4-CVE-2026-109618-109619.patch` | Upstream commit `712e60f9edfd03f0960fc4fc3c2c375f42b90aa2` ("Avoid state corruption via bailout", Arnaud Le Blanc and Ilija Tovilo) from php-src branch `PHP-7.4-CVE-2026-109618-109619`. It targets 7.4.33. SHA-256 `410c984e7abae9834b336cb00d3153428c7fa9b8a8527c65896ed9a72ebb01fe` |
| `harness/` | Container definition, scripts and test pages behind every result below. |
| `logs/` | Raw outputs. Full test-suite logs are gzipped. |

## How the backport differs from upstream

The upstream commit targets 7.4.33. On 7.4.21:

- **15 files** take upstream's changes unchanged. `main/main.c` and `main/php_variables.c` apply a few lines higher.
- **`Zend/zend_vm_def.h`** conflicts, because 7.4.21 does not yet have the CONCAT overflow check that a later 7.4 release added. The `ZEND_CONCAT` and `ZEND_FAST_CONCAT` handlers are brought to the exact state of upstream's patched 7.4.33. The handler bodies are byte-identical, and no other part of the VM is touched.
- **`Zend/zend_vm_execute.h`** is regenerated with the tree's own `Zend/zend_vm_gen.php`, not edited by hand. Two controls show the generator is reliable: it reproduces stock 7.4.21's file byte for byte, and also upstream's patched 7.4.33 file. The opcode tables (`zend_vm_opcodes.*`, `zend_vm_handlers.h`) do not change.
- **`Zend/zend_string.h`** gains `ZSTR_MAX_OVERHEAD` and `ZSTR_MAX_LEN`. These are two macros the overflow checks need, and the header is now identical to 7.4.33's.

## Test environment

A CentOS 7.9 container (`docker.io/library/centos:7`, packages from vault.centos.org) with gcc 4.8.5, glibc 2.17 and
`Apache/2.4.6 (CentOS)` running mod_php under the prefork MPM. Three builds use the same configure line
(mod_php, CLI and CGI, plus openssl, zlib, curl, mbstring, mysqli/pdo_mysql and opcache):

| Build | Source |
|---|---|
| `7.4.21-orig` | Official 7.4.21 tarball, SHA-256 checked against php.net |
| `7.4.21-fix` | The same tarball plus this backport |
| `7.4.33-fix` | Official 7.4.33 tarball plus the upstream commit: the reference for expected behaviour |

## Results

### 1. Request handling through php-cgi (`logs/behaviour-*.log`)

| Check | 7.4.21-orig | 7.4.21-fix | 7.4.33-fix |
|---|---|---|---|
| `max_multipart_body_parts=3`, 10 form fields | 10 parsed (setting unknown) | **3 parsed** | 3 parsed |
| Duplicate `Content-Disposition` plus 300 junk part headers | `{"first":"hello"}` | `{"first":"hello"}` | `{"first":"hello"}` |
| 1 MiB file upload | OK | OK | OK |
| `memory_limit` hit while parsing the request | exit 255 (normal shutdown runs) | **exit 1, immediate `_exit`** | exit 1, immediate `_exit` |
| `memory_limit` hit inside the script | Fatal error page, shutdown handler runs | **no output, exit 1, shutdown handler skipped** | the same |

### 2. Apache mod_php with a single worker process (`logs/apache-*.log`)

Every request goes to the same prefork child, so you can see whether a worker
keeps serving after a request that ran out of memory. That surviving state is
what CVE-2026-109619 abuses.

| Check | 7.4.21-orig | 7.4.21-fix | 7.4.33-fix |
|---|---|---|---|
| 6 MB POST over `memory_limit` (fails while parsing) | HTTP 200, **same worker keeps serving** | connection closed, **worker replaced** | worker replaced |
| `memory_limit` hit inside the script | Fatal error page, same worker | connection closed, worker replaced | worker replaced |
| GET with 32 nested array keys | OK | OK, identical output (same md5) | OK, identical output |
| Nested urlencoded POST, 1 MiB multipart upload, session over 2 requests | OK | OK, identical output | OK, identical output |

### 3. PHP's bundled test suite (`logs/suite-*`)

| | Tests run | Passed | Failed |
|---|---|---|---|
| 7.4.21-orig | 11,171 | 11,089 | 47 |
| 7.4.21-fix | 11,171 | 11,081 | 55 |
| 7.4.33-fix | 11,215 | 11,125 | 55 |

The patched build has 9 more failing tests than unpatched 7.4.21. Upstream's patched 7.4.33 fails the same 9 tests, the same way:

- **8 × `ext/session/tests/rfc1867*.phpt`.** Session upload progress is now always `NULL`, because the mitigation switches the feature off.
- **`tests/lang/bug45392.phpt`.** The test sends errors to stderr, and the new error path prints `"\nFatal error: …"` there, so its output gains one blank line. Nothing else differs.

There is one more difference: `ext/date/tests/bug73837.phpt` fails on the unpatched build and passes on the patched one. That test is known to fail at random, because it depends on microsecond timing.

### 4. Binary compatibility (`logs/abi-apcu.log`)

- **ABI identifiers** are the same in all three builds: `PHP API 20190902`, `Zend Extension 320190902`, NTS.
- **Exported symbols of `libphp7.so`:** none removed. Two are added, `zend_mm_safe_error_ex` and `zend_new_array_singleton`.
- **Installed headers:** no `struct`, `union` or `typedef` line changes. The changes are new macros and declarations, plus changed bodies of macros and inline functions (`HT_HASH_RESET`, `zend_safe_address_guarded`, `zend_safe_addmult`). In php-src those are used only by the engine and by bundled extensions (opcache, standard, pcre), which are rebuilt with PHP. APCu uses none of them.
- **APCu 5.1.21 compiled once against unpatched 7.4.21,** then loaded without recompiling: it passes 56/56 of its own tests (11 skipped) on 7.4.21-orig, 7.4.21-fix and 7.4.33-fix.

Other extensions should be checked the same way, for example with `grep` for the three
names above. Use the opcache build that comes out of the same PHP build.

## Behaviour changes to expect in production

These come from upstream's minimal mitigation. The backport reproduces them exactly.

1. **Running out of `memory_limit` now ends the process immediately.** The visitor gets
   an empty reply instead of a 500 page, which a CDN usually turns into a 502.
   `register_shutdown_function` handlers do not run, and neither does Symfony's
   ErrorHandler or Monolog. Apache starts a new worker.
2. **Where the error message goes.** It is written to stderr. That reaches Apache's
   `error_log` when httpd runs in the foreground: CentOS 7's `httpd.service` uses
   `-DFOREGROUND`, and this was verified in the container. It is **lost when httpd is
   daemonised** with `httpd -k start`: APR reopens stderr on `/dev/null` as a fully
   buffered stream, and `_exit()` skips the flush. This was verified with strace.
   An optional one-line hardening is `fflush(stderr);` before `_exit(1)` in
   `zend_mm_safe_error_ex()`, which upstream only does on Windows. It is not
   included, so the backport stays identical to upstream.
3. **`session.upload_progress` is disabled** regardless of `php.ini`.
4. **Multipart parsing is stricter.** A new ini setting, `max_multipart_body_parts`,
   defaults to `max_input_vars + max_file_uploads`. Part headers other than
   `Content-Disposition` and `Content-Type` are ignored, and so are duplicates.

## Limits

- **This fixes PHP2Shell only.** 7.4.21 still lacks the security fixes released in
  7.4.22 through 7.4.33 (see <https://www.php.net/ChangeLog-7.php>). The PHP
  project also calls its 7.4 backport a "minimal mitigation", and says updating
  to a fixed release is the only complete fix.
- **If PHP is rebuilt anyway, 7.4.33 + the upstream branch is the better build.**
  It keeps the same no-recompile property (same `20190902` API, and the same
  APCu binary passes there too), and it adds those twelve releases of fixes.

## Operating-system options

- **Use packages, with no self-compiling.** EL9 (AlmaLinux or Rocky Linux 9, supported
  until 2032) or EL8 (until 2029), plus Remi's PHP 7.4 packages, plus the distribution's
  own Apache 2.4. Remi's 7.4.33 build is reported to include the PHP2Shell
  mitigation; check with `rpm -q --changelog php-common | grep CVE-2026-109618`.
  The old Apache 2.4.6 is not needed: configurations carry over within the 2.4
  series, and the PHP packages are built for the distribution's Apache. This is
  also the moment to switch from mod_php to PHP-FPM, because PHP's advisory rates
  mod_php as the highest-risk setup for these CVEs. CentOS 7 can be upgraded in
  place to AlmaLinux with ELevate.
- **Fedora is a poor fit.** Each release is supported for about 13 months, and PHP
  7.4 does not build against OpenSSL 3 (Fedora's and EL9's version) without patches.
- **The lasting fix** is PHP 8.2 or later, which for a Symfony 2.x application means
  upgrading the framework.

## Reproduce

Requirements: podman, about 3 GB of disk, network access. All builds and tests run inside the container.

```bash
H=$PWD/php2shell-backport-7.4.21   # run from the root of a checkout of this branch
mkdir -p ../dak/{dl,work,inst,logs} && cd ../dak
cp -r $H/harness/scripts $H/harness/www .
for v in 7.4.21 7.4.33; do curl -sSfLo dl/php-$v.tar.xz https://www.php.net/distributions/php-$v.tar.xz; done
curl -sSfLo dl/apcu-5.1.21.tgz https://pecl.php.net/get/apcu-5.1.21.tgz
for d in 7.4.21-orig 7.4.21-fix 7.4.33-fix; do mkdir -p work/$d; tar -xJf dl/php-${d%-*}.tar.xz -C work/$d --strip-components=1; done
mkdir -p work/apcu && tar -xzf dl/apcu-5.1.21.tgz -C work/apcu --strip-components=1 apcu-5.1.21
(cd work/7.4.21-fix && patch -p1 < $H/php-7.4.21-CVE-2026-109618-109619.patch)
(cd work/7.4.33-fix && patch -p1 < $H/upstream-PHP-7.4-CVE-2026-109618-109619.patch)
podman build -t dak-c7 -f scripts/Containerfile scripts
run() { podman run --rm -v "$PWD":/dak:z dak-c7 "$@"; }
for t in 7.4.21-orig 7.4.21-fix 7.4.33-fix; do run /dak/scripts/build.sh $t; done
for t in 7.4.21-orig 7.4.21-fix 7.4.33-fix; do
  run /dak/scripts/behaviour.sh $t; run /dak/scripts/apache-test.sh $t; run /dak/scripts/suite.sh $t
done
run bash -c '/dak/scripts/abi.sh; /dak/scripts/apcu.sh'
# VM regeneration control: run /dak/scripts/regen-vm.sh /dak/inst/7.4.21-orig/bin/php 7.4.21-orig
```
