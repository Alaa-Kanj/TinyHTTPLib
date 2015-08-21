# TinyHTTPLib
A tiny NetLinx native HTTP library based loosely on 'gHttp (HttpImpl)', http lib' and 'cURL'.

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

NetLinx has no support for the default blocking mode (waiting for return data) that a TCP socket is in. (as far as I can see)
To get around this limitation, the HTTP functions return a number (seq).
