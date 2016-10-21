=begin
  Jekyll tag to include Markdown text from _includes directory preprocessing with Liquid.
  Usage:
    {% markdown <filename> %}
  Dependency:
    - kramdown
=end
module Jekyll
  class MarkdownTag < Liquid::Tag
    def initialize(tag_name, text, tokens)
      super
      @text = text.strip
    end
    require "kramdown"
    def render(context)
      site = context.registers[:site]
      if @tag_name == 'markdown' then
        fname = File.join site.source, "_includes", @text
      else
        page = context.registers[:page]
        fname = File.join site.source, File.dirname(page['path']), @text
      end
      tmpl = Liquid::Template.parse(File.read fname).render site.site_payload
      html = Kramdown::Document.new(tmpl).to_html
    end
  end
end
Liquid::Template.register_tag('markdown', Jekyll::MarkdownTag)
Liquid::Template.register_tag('markdown_relative', Jekyll::MarkdownTag)
