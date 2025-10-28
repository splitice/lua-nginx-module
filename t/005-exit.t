# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua;

#repeat_each(20000);
#repeat_each(200);
repeat_each(2);
#master_on();
#workers(1);
#log_level('debug');
#log_level('warn');
#worker_connections(1024);

plan tests => repeat_each() * (blocks() * 3 + 2);

$ENV{TEST_NGINX_MEMCACHED_PORT} ||= 11211;
$ENV{TEST_NGINX_MYSQL_PORT} ||= 3306;

our $LuaCpath = $ENV{LUA_CPATH} ||
    '/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;';

#$ENV{LUA_PATH} = $ENV{HOME} . '/work/JSON4Lua-0.9.30/json/?.lua';

no_long_string();

run_tests();

__DATA__

=== TEST 1: throw 403
--- config
    location /lua {
        content_by_lua "ngx.exit(403);ngx.say('hi')";
    }
--- request
GET /lua
--- error_code: 403
--- response_body_like: 403 Forbidden
--- no_error_log
[error]



=== TEST 2: throw 404
--- config
    location /lua {
        content_by_lua "ngx.exit(404);ngx.say('hi');";
    }
--- request
GET /lua
--- error_code: 404
--- response_body_like: 404 Not Found
--- no_error_log
[error]



=== TEST 3: throw 404 after sending the header and partial body
--- config
    location /lua {
        content_by_lua "ngx.say('hi');ngx.exit(404);ngx.say(', you')";
    }
--- request
GET /lua
--- error_log
attempt to set status 404 via ngx.exit after sending out the response status 200
--- no_error_log
[alert]
--- response_body
hi




=== TEST 10: throw 0
--- config
    location /lua {
        content_by_lua "ngx.say('Hi'); ngx.eof(); ngx.exit(0);ngx.say('world')";
    }
--- request
GET /lua
--- error_code: 200
--- response_body
Hi
--- no_error_log
[error]



=== TEST 11: pcall safe
--- config
    location /lua {
        content_by_lua '
            local function f ()
                ngx.say("hello")
                ngx.exit(200)
            end

            pcall(f)
            ngx.say("world")
        ';
    }
--- request
GET /lua
--- error_code: 200
--- response_body
hello
--- no_error_log
[error]



=== TEST 12: 501 Method Not Implemented
--- config
    location /lua {
        content_by_lua '
            ngx.exit(501)
        ';
    }
--- request
GET /lua
--- error_code: 501
--- response_body_like: 501 (?:Method )?Not Implemented
--- no_error_log
[error]



=== TEST 13: 501 Method Not Implemented
--- config
    location /lua {
        content_by_lua '
            ngx.exit(ngx.HTTP_METHOD_NOT_IMPLEMENTED)
        ';
    }
--- request
GET /lua
--- error_code: 501
--- response_body_like: 501 (?:Method )?Not Implemented
--- no_error_log
[error]



=== TEST 14: throw 403 after sending out headers with 200
--- config
    location /lua {
        rewrite_by_lua '
            ngx.send_headers()
            ngx.say("Hello World")
            ngx.exit(403)
        ';
    }
--- request
GET /lua
--- response_body
Hello World
--- error_log
attempt to set status 403 via ngx.exit after sending out the response status 200
--- no_error_log
[alert]



=== TEST 15: throw 403 after sending out headers with 403
--- config
    location /lua {
        rewrite_by_lua '
            ngx.status = 403
            ngx.send_headers()
            ngx.say("Hello World")
            ngx.exit(403)
        ';
    }
--- request
GET /lua
--- response_body
Hello World
--- error_code: 403
--- no_error_log
[error]
[alert]



=== TEST 16: throw 403 after sending out headers with 403 (HTTP 1.0 buffering)
--- config
    location /t {
        rewrite_by_lua '
            ngx.status = 403
            ngx.say("Hello World")
            ngx.exit(403)
        ';
    }
--- request
GET /t HTTP/1.0
--- response_body
Hello World
--- error_code: 403
--- no_error_log
[error]
[alert]



=== TEST 17: throw 444 after sending out responses (HTTP 1.0)
--- config
    location /lua {
        content_by_lua "
            ngx.say('ok');
            return ngx.exit(444)
        ";
    }
--- request
GET /lua HTTP/1.0
--- ignore_response
--- log_level: debug
--- no_error_log
lua sending HTTP 1.0 response headers
[error]



=== TEST 18: throw 499 after sending out responses (HTTP 1.0)
--- config
    location /lua {
        content_by_lua "
            ngx.say('ok');
            return ngx.exit(499)
        ";
    }
--- request
GET /lua HTTP/1.0
--- ignore_response
--- log_level: debug
--- no_error_log
lua sending HTTP 1.0 response headers
[error]



=== TEST 19: throw 408 after sending out responses (HTTP 1.0)
--- config
    location /lua {
        content_by_lua "
            ngx.say('ok');
            return ngx.exit(408)
        ";
    }
--- request
GET /lua HTTP/1.0
--- ignore_response
--- log_level: debug
--- no_error_log
lua sending HTTP 1.0 response headers
[error]



=== TEST 20: exit(201) with custom response body
--- config
    location = /t {
        content_by_lua "
            ngx.status = 201
            ngx.say('ok');
            return ngx.exit(201)
        ";
    }
--- request
    GET /t
--- ignore_response
--- log_level: debug
--- no_error_log
lua sending HTTP 1.0 response headers
[error]
[alert]



=== TEST 21: exit 403 in header filter
--- config
    location = /t {
        content_by_lua "ngx.say('hi');";
        header_filter_by_lua '
            return ngx.exit(403)
        ';
    }
--- request
GET /t
--- error_code: 403
--- response_body_like: 403 Forbidden
--- no_error_log
[error]



=== TEST 22: exit 201 in header filter
--- config
    lingering_close always;
    location = /t {
        content_by_lua "ngx.say('hi');";
        header_filter_by_lua '
            return ngx.exit(201)
        ';
    }
--- request
GET /t
--- error_code: 201
--- response_body
--- no_error_log
[error]



=== TEST 23: exit both in header filter and content handler
--- config
    location = /t {
        content_by_lua "ngx.status = 201 ngx.say('hi') ngx.exit(201)";
        header_filter_by_lua '
            return ngx.exit(201)
        ';
    }
--- request
GET /t
--- error_code: 201
--- stap2
/*
F(ngx_http_send_header) {
    printf("=== %d\n", $r->headers_out->status)
    print_ubacktrace()
}
*/
F(ngx_http_lua_header_filter_inline) {
    printf("=== %d\n", $r->headers_out->status)
    print_ubacktrace()
}
F(ngx_http_lua_header_filter_by_chunk).return {
    if ($return == -1) {
        printf("====== header filter by chunk\n")
        print_ubacktrace()
    }
}
--- stap_out
--- response_body
--- no_error_log
[error]
[alert]



=== TEST 24: exit 444 in header filter
--- config
    location = /t {
        content_by_lua "ngx.say('hello world');";
        header_filter_by_lua '
            return ngx.exit(444)
        ';
    }
--- request
GET /t
--- error_code: 444
--- response_body
--- no_error_log
[error]



=== TEST 25: 501 Method Not Implemented
--- config
    location /lua {
        content_by_lua '
            ngx.exit(ngx.HTTP_NOT_IMPLEMENTED)
        ';
    }
--- request
GET /lua
--- error_code: 501
--- response_body_like: 501 (?:Method )?Not Implemented
--- no_error_log
[error]



=== TEST 26: accepts NGX_OK
--- config
    location = /t {
        content_by_lua_block {
            ngx.exit(ngx.OK)
        }
    }
--- request
GET /t
--- response_body
--- no_error_log
[error]



=== TEST 27: accepts NGX_ERROR
--- no_http2
--- config
    location = /t {
        content_by_lua_block {
            ngx.exit(ngx.ERROR)
        }
    }
--- request
GET /t
--- error_code:
--- response_body
--- no_error_log
[error]
--- curl_error
curl: (95) HTTP/3 stream 0 reset by server



=== TEST 28: accepts NGX_DECLINED
--- no_http2
--- config
    location = /t {
        content_by_lua_block {
            ngx.exit(ngx.DECLINED)
        }
    }
--- request
GET /t
--- error_code:
--- response_body
--- no_error_log
[error]
--- curl_error
curl: (95) HTTP/3 stream 0 reset by server



=== TEST 29: refuses NGX_AGAIN
--- config
    location = /t {
        content_by_lua_block {
            ngx.exit(ngx.AGAIN)
        }
    }
--- request
GET /t
--- error_code: 500
--- response_body_like: 500 Internal Server Error
--- error_log eval
qr/\[error\] .*? bad argument to 'ngx.exit': does not accept NGX_AGAIN or NGX_DONE/



=== TEST 30: refuses NGX_DONE
--- config
    location = /t {
        content_by_lua_block {
            ngx.exit(ngx.DONE)
        }
    }
--- request
GET /t
--- error_code: 500
--- response_body_like: 500 Internal Server Error
--- error_log eval
qr/\[error\] .*? bad argument to 'ngx.exit': does not accept NGX_AGAIN or NGX_DONE/
