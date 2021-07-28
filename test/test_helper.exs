Mox.defmock(BitPalPhx.HTTPMock, for: BitPalPhx.HTTPClientAPI)
Application.put_env(:demo, :http_client, BitPalPhx.HTTPMock)

Mox.defmock(BitPalPhx.SocketMock, for: BitPalPhx.SocketAPI)
Application.put_env(:demo, :socket_client, BitPalPhx.SocketMock)

ExUnit.start()
