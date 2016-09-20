#! /usr/bin/env lsc
require! {
    fs
    net
    url
    'node-fetch' : fetch
    'prelude-ls' : { compact, split, map }
    'async/series' : series
}


report = (link, status) ->
    console.log "#{status}\t#{link}"


check-http = (parsed-url, callback) ->
    fetch(parsed-url.href, { timeout: 10000, compress: false }).then (response) ->
        report parsed-url.href, response.status
        callback null
    .catch (err) ->
        | err.type == \request-timeout => report parsed-url.href, \t.o
        | otherwise => report parsed-url.href, \err
        callback null


check-tcp = (parsed-url, callback) ->
    sock = tmo = null
    try
        sock := net.connect split-host-port parsed-url
    catch
        report parsed-url.href, \exc
        callback null
        return
    sock
        ..on \error !->
            clear-timeout tmo
            report parsed-url.href, \err
            sock
                ..end!
                ..destroy!
            callback null
        ..on \connect !->
            clear-timeout tmo
            report parsed-url.href, ' ok'
            sock.end!
            callback null
    tmo = set-timeout !->
        sock
            ..end!
            ..destroy!
        report parsed-url.href, \t.o
        callback null
    , 10000


validate-url = (input) ->
    parsed-url = url.parse input
    is-http = parsed-url.slashes &&
        (parsed-url.protocol == 'http:' ||
         parsed-url.protocol == 'https:')
    [parsed-url, is-http]


split-host-port = (parsed-url) ->
    # possibly has this format: protocol://hostname:port/pathname
    # if port is not specified then it's an error
    # since http URLs should not passed here.
    | parsed-url.slashes => host: parsed-url.hostname, port: parsed-url.port

    # if slashes is null but protocol is exist
    | parsed-url.protocol =>
        host: parsed-url.protocol.substring(0, parsed-url.protocol.length - 1),
        port: parsed-url.hostname

    # this is an error
    | otherwise => host: parsed-url.pathname, port: null


do-check = (line, callback) ->
    [u, is-http] = validate-url line
    switch
    | is-http => check-http u, callback
    | otherwise => check-tcp u, callback


input-file = process.argv.2 || './test.list'

fs.read-file-sync input-file, 'utf8'
    |> split '\n'
    |> compact
    |> map ((elm) -> (callback) -> do-check elm, callback)
    |> series
