use inc::Module::Install;
name 'WWW-AutoPagerize';
all_from 'lib/WWW/AutoPagerize.pm';

requires 'HTML::TreeBuilder::XPath';
requires 'JSON::Any';
requires 'URI';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
auto_include;
WriteAll;
