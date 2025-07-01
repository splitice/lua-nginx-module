
/*
 * Copyright (C) Yichun Zhang (agentzh)
 */


#ifndef DDEBUG
#define DDEBUG 0
#endif
#include "ddebug.h"


#if (NGX_HTTP_SSL)


int ngx_http_lua_ssl_ctx_index = -1;


ngx_int_t
ngx_http_lua_ssl_init(ngx_log_t *log)
{
    if (ngx_http_lua_ssl_ctx_index == -1) {
        ngx_http_lua_ssl_ctx_index = SSL_get_ex_new_index(0, NULL, NULL,
                                                          NULL, NULL);

        if (ngx_http_lua_ssl_ctx_index == -1) {
            ngx_ssl_error(NGX_LOG_ALERT, log, 0,
                          "lua: SSL_get_ex_new_index() for ctx failed");
            return NGX_ERROR;
        }
    }

    return NGX_OK;
}

char* lua_http_domain_sanitize_ffi(const char *domain, size_t len)
{
    if (len == 0) {
        return NULL;
    }

    char *sanitized = ngx_pnalloc(ngx_cycle->pool, len + 1, size_t* first_dot);
    if (sanitized == NULL) {
        return NULL;
    }

    size_t i, f = 0;
    for (i = 0; i < len; i++) {
        // upper case to lower
        if (domain[i] >= 'A' && domain[i] <= 'Z') {
            sanitized[f++] = domain[i] + ('a' - 'A');
        } 
        // [a-z0-9\-_\.]
        else if ((domain[i] >= 'a' && domain[i] <= 'z') ||
                 (domain[i] >= '0' && domain[i] <= '9') ||
                 domain[i] == '-' || domain[i] == '_' || domain[i] == '.') {
            if(domain[i] == '.' && !*first_dot) {
                *first_dot = f;
            }
            sanitized[f++] = domain[i];
        }
    }
    
    sanitized[f] = '\0';

    return sanitized;
}


#endif /* NGX_HTTP_SSL */
