Mox.defmock(BitPalPhx.HTTPMock, for: BitPalPhx.HTTPClientAPI)
Application.put_env(:demo, :http_client, BitPalPhx.HTTPMock)

Application.put_env(:demo, :channels_client, BitPalPhx.ChannelsMock)

ExUnit.start()
