#! /usr/bin/env lsc
require! {
    fs
    net
    url
    'node-fetch' : fetch
    'prelude-ls' : { compact, each, split }
}


report = (link, status) ->
    console.log "#{status}\t#{link}"


check-http = (parsed-url) ->
    fetch(parsed-url.href, { timeout: 10000 }).then (response) ->
        report parsed-url.href, response.status
    .catch (err) ->
        if err.type == \request-timeout
            report parsed-url.href, \t.o
        else
            report parsed-url.href, \err


check-tcp = (parsed-url) ->
    sock = tmo = null
    try
        sock := net.connect split-host-port parsed-url
    catch
        report parsed-url.href, \exc
        return
    sock
        ..on \error !->
            clear-timeout tmo
            report parsed-url.href, \err
            sock
                ..end!
                ..destroy!
        ..on \connect !->
            clear-timeout tmo
            report parsed-url.href, ' ok'
            sock.end!
    tmo = set-timeout !->
        sock
            ..end!
            ..destroy!
        report parsed-url.href, \t.o
    , 10000


validate-url = (input) ->
    parsed-url = url.parse input
    is-http = parsed-url.slashes && (parsed-url.protocol == 'http:' || parsed-url.protocol == 'https:')
    [parsed-url, is-http]


split-host-port = (parsed-url) ->
    # possibly has this format protocol://hostname:port/pathname
    if parsed-url.slashes
        { host: parsed-url.hostname, port: parsed-url.port } # if port is not specified then it's an error since http URLs should not passed here
    else if parsed-url.protocol
        { host: parsed-url.protocol.substring(0, parsed-url.protocol.length - 1), port: parsed-url.hostname } # if slashes is null but protocol is exist
    else
        { host: parsed-url.pathname, port: null } # this is an error


input-file = process.argv.2 || './test.list'

fs.read-file-sync input-file, 'utf8' |> split '\n' |> compact |> each (line) ->
    [u, is-http] = validate-url line
    if is-http
        check-http u
    else
        check-tcp u
