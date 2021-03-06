require 'rubygems'
require 'nokogiri'
require 'eeepub'
require 'jekyll'
require 'css_parser'

# Based on http://gist.github.com/424892. Thanks!

DOC_TITLE = "why's (poignant) Guide to Ruby"

# Thanks Phrogz! http://stackoverflow.com/a/4841269/847536
class Nokogiri::XML::Node
  def add_css_class( *classes )
    existing = (self['class'] || "").split(/\s+/)
    self['class'] = existing.concat(classes).uniq.join(" ")
  end
end

def clean_page(src_dir, chapter_path)
  # make all pages xml complient
  # as well as making some layout optimisations
  doc = File.open(File.join(src_dir, "book", chapter_path)) { |f| Nokogiri::HTML(f) }
  case chapter_path
  when "index.html"
    doc.at_css('#wrapper').prepend_child( doc.at_css('#bookcontents') )
    doc.at_css('#sidepane').unlink
    doc.at_css('body').prepend_child( doc.at_css('#main') )
    doc.at_css('#main').prepend_child( doc.at_css('#wrapper') )
    doc.at_css('.foxbox').unlink
    doc.css("a").each do |link|
      case link['href']
      when /^chapter-\d+\.html/, /^expansion-pak-\d+\.html/
        link["href"] = "book/"+link["href"]
      when "../dwemthy/"
        link["href"] = link["href"].sub(/\.\.\//,"")+"index.html"
      end
    end
  when /^chapter-\d+\.html/, /^expansion-pak-\d+\.html/
    doc.at_css('body').add_child( doc.at_css('.pageTitle') )
    doc.at_css('body').add_child( doc.at_css('.content') )
    doc.css('#banner').unlink
    doc.css('#container').unlink
    doc.css("p > img").each do |img|
      img.parent.add_css_class('img');
    end
    doc.css("p > a").each do |link|
      if link.content === "Turn page."
        link.parent.unlink
      end
    end
  end
  doc.css('script').unlink
  File.write(File.join(src_dir, "book", chapter_path), doc.to_xhtml( encoding:'US-ASCII' ) )
end

def get_pages(src_dir)
  index_file = File.join(src_dir, 'book/index.html') 
  section = nil
  pages = [{ index_file => ".", :section => nil, :title => DOC_TITLE, :path => index_file }]

  Nokogiri::HTML(open(index_file)).css("#bookcontents > ol > li > a").each do |chapter|

    chapter_path = chapter.attributes["href"].to_s
    dest_dir = "book"
    if File.directory?( File.join(src_dir, "book", chapter_path) )
      # .sub needed for Dwemthy's Array link in toc
      chapter_path = chapter_path.sub(/\/*$/, "/index.html")
      dest_dir = File.dirname( chapter_path ).sub(/^\.*\/*/,"")
    end

	clean_page(src_dir, chapter_path)

    pages << {
      File.join(src_dir, "book", chapter_path) => dest_dir,
      :section => nil,
      :title => chapter.content,
      :path => File.join("book",chapter.attributes["href"])
    }
	next;
    chapter.parent.parent.search("ol/li/a").each do |section|
      pages << {
        :section => chapter.content,
        :title => section.content,
        :path => File.join( "book", section.attributes["href"])
      }
    end
  end

  clean_page(src_dir, 'index.html')

  pages
end

def get_images(src_dir)
  images = []

  Dir.glob(File.join(src_dir, 'images', '**/*.{png,gif,jpg}')).each do |path|
    flag = false
    tokens = path.split(File::SEPARATOR).find_all do |token|
      flag = true if token == 'images'
      flag && ! token.match(/.+\.(png|gif|jpg)$/)
    end

    images << { path => tokens.join(File::SEPARATOR), :path => path, :dir => tokens.join(File::SEPARATOR)}
  end

  images
end

def get_styles(src_dir)
  parser = CssParser::Parser.new
  parser.load_uri!(File.join(src_dir, 'guide.css'))
  # add a block of CSS
  css = <<-EOT
    body, body.expansion {
      initial;
      padding: 0px
    }
    .sidebar { 
      width: initial;
      float: initial;
      padding: initial;
      z-index: initial;
      margin: 15px 0px;
    }
    .pageTitle {
      width: initial;
      max-width: 600px;
    }
    * {
      max-width: 100%;
    }
    p {
      margin: 1em;
      padding: 0;
    }
    p.img {
      margin: 0px;
    }
    p img, .content img {
      display: block;
      margin: auto;
    }
    pre,code {
      word-wrap: break-word;      /* IE 5.5-7 */
      white-space: -moz-pre-wrap; /* Firefox 1.0-2.0 */
      white-space: pre-wrap;      /* current browsers */
    }
    .sidebar:after {
      content: "End Sidebar!";
    }
    .content h2 {
      margin: 35px 15px 15px;
    }
    .content h3 {
      margin: 18px 15px 15px;
    }
  EOT

  parser.add_block!(css)
  File.write(File.join(src_dir, 'guide.css'), parser )
  [{ File.join(src_dir, 'guide.css') => '.', :path => "guide.css", :dir => src_dir},
   { File.join(src_dir, 'dwemthy/dwemthy.css') => 'dwemthy'}]
end

def get_creators(src_dir)
  credits_file = File.join(src_dir, 'credits.html')

  Nokogiri::HTML(open(credits_file)).css("h3").find_all { |elm|
    ! elm.attr('class')
  }.map { |elm| elm.content }
end

def get_nav(pages)
  section = nil
  sec_num = chap_num = 0

  secid = "abcdefghijklmnopqrstuvwxyz".split("")

  pages.inject([]) do |nav, page|
    content = File.basename(page[:path])

    if page[:section].nil?
      nav << { :label => page[:title], :content => content }
    elsif section != page[:section]
      sec_num += 1
      nav << {
        :label => "#{sec_num}. #{page[:section]}",
        :content => content,
          :nav => [{
          :label => "#{sec_num}. #{page[:title]}",
        :content => content
        }]
      }  
      chap_num = 0
      section = page[:section]
    else
      nav.last[:nav] << {
        :label => "#{sec_num}.#{secid[chap_num]}. #{page[:title]}",
        :content => content
      } unless nav.empty?
      chap_num += 1
    end

    nav
  end
end

if __FILE__ == $0
  src_dir = File.join( File.dirname(__FILE__), "html/" )

  # build html
  conf = Jekyll.configuration({
    'source'      => 'poignant-guide/',
    'destination' => src_dir
  })
  Jekyll::Site.new(conf).process

  pages = get_pages(src_dir)
  images = get_images(src_dir)
  styles = get_styles(src_dir)

  epub = EeePub.make do
    title       DOC_TITLE
    creator     'why the lucky stiff'
    publisher   'why the lucky stiff'
    cover       'cover.jpg'
    date        Time.now.strftime('%Y-%m-%d')
    identifier  'http://poignant.guide', :scheme => 'URL'
    uid         'whys-poignant-guide-to-ruby'

    files pages + images + styles + [{ File.join(src_dir, '../cover.jpg') => '.' }]
    nav get_nav(pages)
  end

  epub.save('./poignant-guide.epub')
end
