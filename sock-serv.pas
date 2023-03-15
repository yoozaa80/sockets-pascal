(*
**	TCP server (multithread) example by using FP's socket unit.
**	Nicholas Christopoulos <nereus@freemail.gr>
*)

Program SocketServer;
{$mode fpc}

Uses
	{$ifdef unix}cthreads, {$endif} Sockets;

(*
**	print error message...
*)
procedure warn(const msg : string);
begin
	WriteLn(msg, '; socket error=', SocketError);
end;

(*
**	send string msg to socket 'sock' and end-of-line
*)
procedure scSendLn(sock : TSocket; const msg : String);
const crlf = #13#10;
var buf : string;
begin
	buf := ConCat(msg, crlf);
	fpSend(sock, @buf[1], length(buf), 1);
end;

(*
**	receive a string from socket 'sock' and return the number of
**	bytes received minus the CRLF.
*)
function scRecvLn(sock : TSocket; var msg : String) : LongInt;
var n : LongInt;
	buf : Array [0..2047] of Char;
begin
	msg := '';
	n := fpRecv(sock, @buf, 2048, 0);
	if n > 0 then begin
		buf[n] := #0;
		while n > 0 do begin
			if (buf[n-1] = #10) or (buf[n-1] = #13) then begin
				n := n - 1;
				buf[n] := #0;
				end
			else
				break;
			end;
		msg := PChar(@buf);
		end;
	scRecvLn := n;
end;

(*
**	returns the first word of the string
*)
function getFirstWord(const source : String) : String;
var	i, start : LongInt;
	s : String;
begin
	s := '';
	for i := 1 to length(source) do
		if source[i] <> ' ' then break;
	start := i;
	for i := start to length(source) do
		if source[i] <> ' ' then s := s + source[i] else break;
	getFirstWord := s;
end;

(*
**	thread-function to serve a connection
**	the 'p' is pointer to the socket of the client.
*)
function clerk(p : pointer) : ptrint;
var sock	 : TSocket;
	n		 : LongInt;
	msg, cmd, cli : String;
begin
	sock := LongInt(p);
	WriteLn('Thread created to serve ', sock, ' client.');
	repeat
		scSendLn(sock, 'Welcome to sock-serv, enter "quit" to end this thread');
		n := scRecvLn(sock, cli);
		if n > 0 then begin
			WriteLn(sock, ' > ', cli);
			cmd := getFirstWord(cli);
			if cmd = 'test' then begin
				scSendLn(sock, '+OK');
				break;
				end;
			msg := '+OK';
			scSendLn(sock, msg);
			WriteLn(sock, ' < ', msg);
			end
		else warn('connection closed');
	until (n <= 0) or (cmd = 'quit');
	fpShutdown(sock, 2);
	CloseSocket(sock);
	WriteLn('Thread closed');
	clerk := 0;
end;

(* === main === *)
Var
	saddr, caddr	: TSockAddr; (* or TUnixSockAddr; *)
	host			: String;
	sock, client	: TSocket;
	domain, protc, port : LongInt;
	csize			: TSockLen;

begin
	host   := 'localhost'; (* or '0.0.0.0' *)
	port   := 4096;
	domain := AF_INET;
	protc  := IPPROTO_TCP;
	sock   := fpSocket(domain, SOCK_STREAM, protc);
	if sock <> -1 then begin
		saddr.sin_family := domain;
		saddr.sin_port   := htons(port);
		saddr.sin_addr   := StrToHostAddr(host);
		if fpBind(sock, @saddr, sizeof(saddr)) = 0 then begin	(* allocate address and port *)
			Writeln('Server started, waiting...');
			if fpListen(sock, 20) = 0 then begin				(* start listen *)
				repeat
					csize  := sizeof(caddr);
  					client := fpAccept(sock, @caddr, @csize);	(* wait for connection, and return the client's socket *)
					if client <> -1 then
						BeginThread(@clerk, pointer(client));	(* dont use pointer of static data *)
				until client = -1;
				end
			else warn('listen failed');
			end
		else warn('bind failed');
		end
	else warn('create socket failed');
end.