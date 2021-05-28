defmodule Demo.LayoutView do
  use Demo, :view
  import Makeup.Styles.HTML.StyleMap

  def highlighted_code(path) do
    contents = :code.priv_dir(:demo) |> Path.join(path) |> File.read!()
    line_count = contents |> String.split("\n") |> Enum.count()

    {Makeup.highlight(contents), line_count}
  end

  def code_stylesheet do
    # Makeup.stylesheet(paraiso_dark_style)
    Makeup.stylesheet(monokai_style())
  end
end
