defmodule Demo.Router do
  use Demo, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {Demo.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", Demo do
    pipe_through :browser

    live "/", PaymentLive, :index
  end
end
