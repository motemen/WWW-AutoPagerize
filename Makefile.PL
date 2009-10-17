use inc::Module::Install;
name 'WWW-AutoPagerize';
all_from 'lib/WWW/AutoPagerize.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
