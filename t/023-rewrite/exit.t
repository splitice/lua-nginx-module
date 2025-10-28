# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua;

#repeat_each(20000);

repeat_each(2);

#master_on();
#workers(1);
#log_level('debug');
#log_level('warn');
#worker_connections(1024);

plan tests => repeat_each() * (blocks() * 2 + 4);

$ENV{TEST_NGINX_MEMCACHED_PORT} ||= 11211;
$ENV{TEST_NGINX_MYSQL_PORT} ||= 3306;

our $LuaCpath = $ENV{LUA_CPATH} ||
    '/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;';

#$ENV{LUA_PATH} = $ENV{HOME} . '/work/JSON4Lua-0.9.30/json/?.lua';

no_long_string();
#no_shuffle();

run_tests();

__DATA__

=== TEST 1: throw 403
--- config
    location /lua {
        rewrite_by_lua "ngx.exit(403);ngx.say('hi')";
        content_by_lua 'ngx.exit(ngx.OK)';
    }
--- request
GET /lua
--- error_code: 403
--- response_body_like: 403 Forbidden



=== TEST 2: throw 404
--- config
    location /lua {
        rewrite_by_lua "ngx.exit(404);ngx.say('hi');";
        content_by_lua 'ngx.exit(ngx.OK)';
    }
--- request
GET /lua
--- error_code: 404
--- response_body_like: 404 Not Found



=== TEST 3: throw 404 after sending the header and partial body
--- config
    location /lua {
        rewrite_by_lua "ngx.say('hi');ngx.exit(404);ngx.say(', you')";
        content_by_lua 'ngx.exit(ngx.OK)';
    }
--- request
GET /lua
--- error_log
attempt to set status 404 via ngx.exit after sending out the response status 200
--- response_body
hi




=== TEST 10: throw 0
--- config
    location /lua {
        rewrite_by_lua "ngx.say('Hi'); ngx.eof(); ngx.exit(0);ngx.say('world')";
        content_by_lua 'ngx.exit(ngx.OK)';
    }
--- request
GET /lua
--- error_code: 200
--- response_body
Hi



=== TEST 11: throw ngx.OK does *not* skip other rewrite phase handlers
--- config
    location /lua {
        rewrite_by_lua "ngx.exit(ngx.OK)";
        set $foo hello;
        echo $foo;
    }
--- request
GET /lua
--- response_body
hello



=== TEST 12: throw ngx.HTTP_OK *does* skip other rewrite phase handlers (by inlined code)
--- config
    location /lua {
        rewrite_by_lua "ngx.exit(ngx.HTTP_OK)";
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



=== TEST 14: throw ngx.HTTP_OK *does* skip other rewrite phase handlers (by file)
--- config
    location /lua {
        rewrite_by_lua_file html/foo.lua;
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
        rewrite_by_lua '
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



=== TEST 17: exit with 204 (HTTP 1.1)
--- config
    location = /t {
        rewrite_by_lua '
            ngx.exit(204)
        ';

        proxy_pass http://127.0.0.1:$server_port/blah;
    }

    location = /blah {
        echo blah;
    }
--- request
GET /t
--- more_headers2
--- stap2
F(ngx_http_send_header) {
    printf("send header\n")
    print_ubacktrace()
}
--- response_body
--- error_code: 204
--- no_error_log
[error]



=== TEST 18: exit with 204 (HTTP 1.0)
--- config
    location = /t {
        rewrite_by_lua '
            ngx.exit(204)
        ';

        proxy_pass http://127.0.0.1:$server_port/blah;
    }

    location = /blah {
        echo blah;
    }
--- request
GET /t HTTP/1.0
--- more_headers2
--- stap2
F(ngx_http_send_header) {
    printf("send header\n")
    print_ubacktrace()
}
--- response_body
--- error_code: 204
--- no_error_log
[error]
