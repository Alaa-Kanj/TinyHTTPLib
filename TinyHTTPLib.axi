#if_not_defined __TinyHTTPLib__
#define __TinyHTTPLib__

/*

TinyHTTPLib
A tiny NetLinx native HTTP library based on 'gHttp (HttpImpl)', http lib' and 'cURL'.


NetLinx has no support for the default blocking mode (waiting for return data) that a TCP socket is in. (as far as I can see)
To get around this limitation, the HTTP functions return a number (seq).

On receipt of a response it will call back to a function http_response_received() which needs to be implimented in your code.
This should contain 3 arguments: the sequence number, the full request object and a parsed response object ready for you to handle.

If you want to handle responses, add #define resp_callback to your code.
If you don't want to handle responses, it can be omited.

Upon an error there will be a call back to http_error() with the correct seq number, host target, the request object and an error number.
If you want to handle errors, add #define err_callback to your code.
If you don't want to handle errors, it can be omited.

It is reasonable to assume that a maximum of 15 parallel requests can be handled at a time.
If you are having connection issues because of a bad network or device, scale this down. If you have to watch overhead, scale this down.
To do this, edit the constant: MAX_REQ.

*/

PROGRAM_NAME = 'TinyHTTPLib'

DEFINE_CONSTANT

// Tweakables
integer MAX_REQ = 15
integer BASE_PORT = 30
integer MAX_REQ_LEN = 4096
integer MAX_RES_LEN = 16384
integer MAX_LINE_LEN = 2048
integer MAX_RESP_TIMEOUT = 1
long    TIMEOUT[] = {7000}

// Error handling
integer ERR_OOM = 2
integer ERR_UNKNOWN_HOST = 4
integer ERR_CONN_REFUSED = 6
integer ERR_CONN_TIMEOUT = 7
integer ERR_UNKNOWN = 8
integer ERR_IS_CLOSED = 9
integer ERR_PORT_USED = 14
integer ERR_TOO_MANY_SOCKETS = 16
integer ERR_PORT_NOT_OPEN = 17
integer ERR_BAD_RESP = 18

char ERR_TXT[][32] = {
    'ERROR 1: 408 - RESPONSE TIMED OUT',
    'ERROR 2: OUT OF MEMORY!',
    'ERROR 3: UNKNOWN',
    'ERROR 4: 001 - UNKNOWN HOST',
    'ERROR 5: UNKNOWN',
    'ERROR 6: 401 / 403 - CONNECTION REFUSED',
    'ERROR 7: 522 - CONNECTION TIMED OUT',
    'ERROR 8: UNKNOWN',
    'ERROR 9: THE LOCAL PORT IS ALREADY CLOSED',
    'ERROR 10: UNKNOWN',
    'ERROR 11: UNKNOWN',
    'ERROR 12: UNKNOWN',
    'ERROR 13: UNKNOWN',
    'ERROR 14: THE LOCAL PORT ALREADY USED',
    'ERROR 15: UNKNOWN',
    'ERROR 16: THERE ARE TOO MANY OPEN SOCKETS',
    'ERROR 17: THE LOCAL PORT IS NOT OPEN',
    'ERROR 18: 400 - BAD REQUEST (MALFORMED RESPONSE)'
}

// Timeout
long TL_1 = 30
long TL_2 = 31
long TL_3 = 32
long TL_4 = 33
long TL_5 = 34
long TL_6 = 35
long TL_7 = 36
long TL_8 = 37
long TL_9 = 38
long TL_10 = 39
long TL_11 = 40
long TL_12 = 41
long TL_13 = 42
long TL_14 = 43
long TL_15 = 44
long TL[] = {
    TL_1,
    TL_2,
    TL_3,
    TL_4,
    TL_5,
    TL_6,
    TL_7,
    TL_8,
    TL_9,
    TL_10,
    TL_11,
    TL_12,
    TL_13,
    TL_14,
    TL_15
}


DEFINE_TYPE

structure http_header {
    char key[64]
    char value[256]
}

structure http_request {
    char method[7]
    char uri[256]
    http_header headers[5]
    char body[2048]
}

structure http_response {
    char version[8]
    integer code
    char message[64]
    http_header headers[10]
    char body[16384]
}

structure http_req_obj {
    long seq
    char host[512]
    http_request request
    char socket_open
}

structure http_url {
    char protocol[16]
    char host[256]
    char uri[256]
}


DEFINE_VARIABLE

volatile dev http_sockets[MAX_REQ]
volatile char http_socket_buff[MAX_REQ][MAX_RES_LEN]
volatile http_req_obj http_req_objs[MAX_REQ]

// Create our seq number to help us with responses
define_function long http_get_seq_id() {
    local_var long next_seq
    stack_var long seq

    if (next_seq == 0) {
        next_seq = 1
    }

    seq = next_seq
    next_seq++

    return seq
}

// Check if we have a slot in use
define_function char http_req_obj_in_use(integer id) {
    return http_req_objs[id].seq > 0
}


// Get the next available slot
define_function integer http_get_req_res() {
    stack_var integer x

    for (x = 1; x <= MAX_REQ; x++) {
        if (http_req_obj_in_use(x) == false) {
            http_req_objs[x].seq = http_get_seq_id()
            return x
        }
    }

    return 0
}

// Release a slot
define_function http_release_res(integer id) {
    stack_var http_req_obj null

    if (timeline_active(TL[id])) {
        timeline_kill(TL[id])
    }

    clear_buffer http_socket_buff[id]

    if (http_req_objs[id].socket_open) {
        ip_client_close(http_sockets[id].port)
    }

    http_req_objs[id] = null
}

// GET request
define_function long http_get(char resource[]) {
    stack_var http_url url
    stack_var http_request request

    http_parse_url("resource", url)

    request.method = 'GET'
    request.body = ''

    return http_exec_req(url, request)
}

// HEAD request
define_function long http_head(char resource[]) {
    stack_var http_url url
    stack_var http_request request

    http_parse_url("resource", url)

    request.method = 'HEAD'
    request.body = ''

    return http_exec_req(url, request)
}

// PUT request
define_function long http_put(char resource[], char body[]) {
    stack_var http_url url
    stack_var http_request request

    http_parse_url("resource", url)

    request.method = 'PUT'
    request.body = body

    return http_exec_req(url, request)
}

// POST request
define_function long http_post(char resource[], char body[]) {
    stack_var http_url url
    stack_var http_request request

    http_parse_url("resource", url)

    request.method = 'POST'
    request.body = body

    return http_exec_req(url, request)
}

// PATCH request
define_function long http_patch(char resource[], char body[]) {
    stack_var http_url url
    stack_var http_request request

    http_parse_url("resource", url)

    request.method = 'PATCH'
    request.body = body

    return http_exec_req(url, request)
}

// DELETE request
define_function long http_delete(char resource[]) {
    stack_var http_url url
    stack_var http_request request

    http_parse_url("resource", url)

    request.method = 'DELETE'

    return http_exec_req(url, request)
}

// Get the http_header value
define_function char[256] http_get_header(http_header headers[],
        char key[]) {
    stack_var integer x

    for (x = 1; x <= length_array(headers); x++) {
        if (headers[x].key == key) {
            return headers[x].value
        }
    }
    
    return ''
}

// Get our request ready for Tx
define_function char[MAX_REQ_LEN] http_build_req(char host[],
        http_request request) {
    stack_var char ret[MAX_REQ_LEN]
    stack_var http_header header
    stack_var integer x

    ret = "request.method, ' ', request.uri, ' HTTP/1.1', $0d, $0a"
    
    ret = "ret, 'Host: ', host, $0d, $0a"
    ret = "ret, 'Connection: Close', $0d, $0a"

    if (request.body != '') {
        ret = "ret, 'Content-Length: ', itoa(length_string(request.body)), $0d, $0a"
        if (request.body[1] == '{' &&
                request.body[length_array(request.body)] == '}') {
            ret = "ret, 'Content-Type: application/json', $0d, $0a"
        }
    }

    for (x = 1; x <= length_array(request.headers); x++) {
        header = request.headers[x]
        if (header.key != '') {
            ret = "ret, header.key, ': ', header.value, $0d, $0a"
        }
    }
    ret = "ret, $0d, $0a"
    
    if (request.body != '') {
        ret = "ret, request.body, $0d, $0a"
        ret = "ret, $0d, $0a"
    }

    return ret
}

// Let's send some requests
// This will return out seq number for handling
define_function long http_exec_req(http_url url, http_request request) {
    stack_var integer i
    stack_var char server_address[256]
    stack_var integer server_port
    stack_var integer pos

    if (url.host == '') {
        amx_log(AMX_ERROR, 'Invalid host.')
        return 0
    }

    request.method = upper_string(request.method)
    if (request.method != 'GET' &&
            request.method != 'HEAD' &&
            request.method != 'POST' &&
            request.method != 'PUT' && 
            request.method != 'DELETE' &&
            request.method != 'TRACE' &&
            request.method != 'OPTIONS' &&
            request.method != 'CONNECT' &&
            request.method != 'PATCH') {
        amx_log(AMX_ERROR, "'Invalid HTTP method in request (', request.method, ').'")
        return 0
    }

    if (request.uri == '') {
        request.uri = url.uri
    }

    if (request.uri[1] != '/' &&
            request.uri != '*' &&
            left_string(request.uri, 7) != 'http://') {
        amx_log(AMX_ERROR, "'Invalid request URI (', request.uri, ').'")
        return 0
    }

    i = http_get_req_res()
    if (i == 0) {
        amx_log(AMX_ERROR, 'TinyHTTPLib resources at capacity. Request dropped.')
        return 0
    }

    http_req_objs[i].host = url.host
    http_req_objs[i].request = request

    pos = find_string(url.host, ':', 1)
    if (pos) {
        server_address = left_string(url.host, pos - 1)
        server_port = atoi(right_string(url.host, length_string(url.host) - pos))
    } else {
        server_address = url.host
        server_port = 80
    }

    ip_client_open(http_sockets[i].port, server_address, server_port, IP_TCP)
    
    // Return the seq number
    return http_req_objs[i].seq
}

// Trim the data ready for parsing
define_function char[MAX_LINE_LEN] http_read_len(char buff[]) {
    stack_var char line[MAX_LINE_LEN]

    line = remove_string(buff, "$0d, $0a", 1)
    line = left_string(line, length_string(line) - 2)

    return line
}

//  Trim out the raw header
define_function http_parse_headers(char buff[], http_header headers[]) {
    stack_var char line[MAX_LINE_LEN]
    stack_var integer pos
    stack_var integer x

    for (x = 1; x <= max_length_array(headers); x++) {
        line = http_read_len(buff)
        if (line == '') {
            break;
        }
        if (left_string(line, 5) != 'HTTP/') {
            pos = find_string(line, ': ', 1)
            headers[x].key = left_string(line, pos - 1)
            headers[x].value = right_string(line, length_string(line) - pos - 1)
        }
    }
    set_length_array(headers, x)
}

// Parse raw HTTP response
define_function char http_parse_resp(char buff[], http_response response) {
    stack_var char line[MAX_LINE_LEN]

    line = http_read_len(buff)
    if (left_string(line, 5) != 'HTTP/') {
        return false
    }
    response.version = left_string(remove_string(line, ' ', 1), 8)
    response.code = atoi(remove_string(line, ' ', 1))
    response.message = line

    http_parse_headers(buff, response.headers)

    response.body = buff

    return true
}

// Break the URL into values
define_function char http_parse_url(char buff[], http_url url) {
    stack_var integer pos
    stack_var char tmp[256]

    pos = find_string(buff, '://', 1)
    if (pos) {
        url.protocol = remove_string(buff, '://', 1)
        url.protocol = left_string(url.protocol, length_string(url.protocol) - 3)
        url.protocol = lower_string(url.protocol)
    } else {
        url.protocol = 'http'
    }

    pos = find_string(buff, '/', 1)
    if (pos) {
        url.host = left_string(buff, pos - 1)
        url.uri = right_string(buff, length_string(buff) - (pos - 1))
    } else {
        url.host = buff
        url.uri = '/'
    }

    return true
}


DEFINE_START

// Lets' get ready to open some connections
{
    stack_var integer x

    for (x = 1; x <= MAX_REQ; x++) {
        http_sockets[x].number = 0
        http_sockets[x].port = BASE_PORT + x - 1
        http_sockets[x].system = system_number
        create_buffer http_sockets[x], http_socket_buff[x]
    }
    set_length_array(http_sockets, MAX_REQ)

    rebuild_event()
}


DEFINE_EVENT

// Handle the objects
data_event[http_sockets] {

    online: {
        stack_var integer i
        stack_var http_req_obj req_obj

        i = get_last(http_sockets)
        
        http_req_objs[i].socket_open = true
        req_obj = http_req_objs[i]

        send_string data.device, http_build_req(req_obj.host, req_obj.request)

        timeline_create(TL[i],
                TIMEOUT,
                1,
                TIMELINE_ABSOLUTE,
                TIMELINE_ONCE)
    }

    offline: {
        stack_var integer i
        stack_var http_req_obj req_obj
        stack_var http_response response

        i = get_last(http_sockets)
        
        http_req_objs[i].socket_open = false
        req_obj = http_req_objs[i]

        if (http_req_obj_in_use(i)) {
            if (http_parse_resp(http_socket_buff[i], response)) {
                
                // Should we handle responses?
                #if_defined resp_callback
                http_response_received(req_obj.seq, req_obj.host, req_obj.request, response)
                #end_if
                //
                
            } else {
                amx_log(AMX_ERROR, "'HTTP parsing error (', ERR_TXT[ERR_BAD_RESP], ').'")
                
                // Should we handle errors?
                #if_defined err_callback
                http_error(req_obj.seq, req_obj.host, req_obj.request, ERR_BAD_RESP)
                #end_if
                //
                
            }

            http_release_res(i)
        }
    }

    onerror: {
        stack_var integer i
        stack_var http_req_obj req_obj

        i = get_last(http_sockets)
        
        http_req_objs[i].socket_open = false
        req_obj = http_req_objs[i]

        amx_log(AMX_ERROR, "'HTTP socket error (', ERR_TXT[data.number], ')'")
        
        // Should we handle errors?
        #if_defined err_callback
        http_error(req_obj.seq, req_obj.host, req_obj.request, data.number)
        #end_if
        //

        http_release_res(i)
    }

    string: {}

}

timeline_event[TL_1]
timeline_event[TL_2]
timeline_event[TL_3]
timeline_event[TL_4]
timeline_event[TL_5]
timeline_event[TL_6]
timeline_event[TL_7]
timeline_event[TL_8]
timeline_event[TL_9]
timeline_event[TL_10]
timeline_event[TL_11]
timeline_event[TL_12]
timeline_event[TL_13]
timeline_event[TL_14]
timeline_event[TL_15] {
    stack_var integer i
    stack_var http_req_obj req_obj

    for (i = 1; i <= length_array(TL); i++){
        if (timeline.id == TL[i]) {
            break
        }
    }

    req_obj = http_req_objs[i]

    amx_log(AMX_ERROR, 'HTTP response timed out')

    #if_defined err_callback
    http_error(req_obj.seq, req_obj.host, req_obj.request, MAX_RESP_TIMEOUT)
    #end_if

    http_release_res(i)
}

#end_if // __TinyHTTPLib__
