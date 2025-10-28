# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua;

#repeat_each(20000);
repeat_each(2);

#master_on();
#workers(1);
#log_level('debug');
#log_level('warn');
#worker_connections(1024);

plan tests => repeat_each() * (blocks() * 2 + 2);

$ENV{TEST_NGINX_MEMCACHED_PORT} ||= 11211;
$ENV{TEST_NGINX_MYSQL_PORT} ||= 3306;

our $LuaCpath = $ENV{LUA_CPATH} ||
    '/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;';

no_long_string();

run_tests();

__DATA__

=== TEST 1: throw 403
--- config
    location /lua {
        access_by_lua "ngx.exit(403);ngx.say('hi')";
        content_by_lua 'ngx.exit(ngx.OK)';
    }
--- request
GET /lua
--- error_code: 403
--- response_body_like: 403 Forbidden



=== TEST 2: throw 404
--- config
    location /lua {
        access_by_lua "ngx.exit(404);ngx.say('hi');";
        content_by_lua 'ngx.exit(ngx.OK)';
    }
--- request
GET /lua
--- error_code: 404
--- response_body_like: 404 Not Found



=== TEST 3: throw 404 after sending the header and partial body
--- config
    location /lua {
        access_by_lua "ngx.say('hi');ngx.exit(404);ngx.say(', you')";
        content_by_lua 'ngx.exit(ngx.OK)';
    }
--- request
GET /lua
--- response_body
hi
--- no_error_log
[alert]
--- error_log
attempt to set status 404 via ngx.exit after sending out the response status 200



=== TEST 10: throw 0
--- config
    location /lua {
        access_by_lua "ngx.say('Hi'); ngx.eof(); ngx.exit(0);ngx.say('world')";
        content_by_lua 'ngx.exit(ngx.OK)';
    }
--- request
GET /lua
--- error_code: 200
--- response_body
Hi



=== TEST 11: throw ngx.OK does *not* skip other later phase handlers
--- config
    location /lua {
        access_by_lua "ngx.exit(ngx.OK)";
        set $foo hello;
        echo $foo;
    }
--- request
GET /lua
--- response_body
hello



=== TEST 12: throw ngx.HTTP_OK *does* skip other later phase handlers (by inlined code)
--- config
    location /lua {
        access_by_lua "ngx.exit(ngx.HTTP_OK)";
        set $foo hello;
        echo $foo;
    }
--- request
GET /lua
--- response_body



=== TEST 13: throw ngx.HTTP_OK *does* skip other rewrite phase handlers (by inlined code + partial output)
--- config
    location /lua {
        rewrite_by_lua "ngx.say('hiya') ngx.exit(ngx.HTTP_OK)";
        set $foo hello;
        echo $foo;
    }
--- request
GET /lua
--- response_body
hiya



=== TEST 14: throw ngx.HTTP_OK *does* skip other later phase handlers (by file)
--- config
    location /lua {
        access_by_lua_file html/foo.lua;
        set $foo hello;
        echo $foo;
    }
--- user_files
>>> foo.lua
ngx.exit(ngx.HTTP_OK)
--- request
GET /lua
--- response_body



=== TEST 15: throw ngx.HTTP_OK *does* skip other rewrite phase handlers (by file + partial output)
--- config
    location /lua {
        rewrite_by_lua_file html/foo.lua;
        set $foo hello;
        echo $foo;
    }
--- user_files
>>> foo.lua
ngx.say("morning")
ngx.exit(ngx.HTTP_OK)
--- request
GET /lua
--- response_body
morning



=== TEST 16: error page with custom body
--- config
    error_page 410 @err;
    location @err {
        echo blah blah;
    }
    location /foo {
        access_by_lua '
            ngx.status = ngx.HTTP_GONE
            ngx.say("This is our own content")
            -- to cause quit the whole request rather than the current phase handler
            ngx.exit(ngx.HTTP_OK)
        ';
        echo Hello;
    }
--- request
    GET /foo
--- response_body
This is our own content
--- error_code: 410



=== TEST 17: exit(404) after I/O
--- config
    error_page 400 /400.html;
    error_page 404 /404.html;
    location /foo {
        access_by_lua '
            ngx.location.capture("/sleep")
            ngx.exit(ngx.HTTP_NOT_FOUND)
        ';
        echo Hello;
    }

    location /sleep {
        echo_sleep 0.002;
    }
--- user_files
>>> 400.html
Bad request, dear...
>>> 404.html
Not found, dear...
--- request
    GET /bah
--- response_body
Not found, dear...
--- error_code: 404
