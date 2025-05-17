import socket

host = "127.0.0.1"
port = 1166  # The same port as used by the server
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((host, port))

# repl
while True:
    try:
        data = input("Enter data to send: ")
        if not data:
            break
        s.sendall(data.encode())
        response = s.recv(1024)
        print("Received:", response.decode())
    except KeyboardInterrupt:
        break
    except Exception as e:
        print(f"An error occurred: {e}")
        break
