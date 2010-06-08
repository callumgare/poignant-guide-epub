require 'rubygems'
require 'nokogiri'
require 'eeepub'

# Based on http://gist.github.com/424892. Thanks!

DOC_TITLE = "why's (poignant) guide to ruby"

def get_pages(src_dir)
  index_file = File.join(src_dir, 'book/index.html') 
  section = nil
  pages = [{ :section => nil, :title => DOC_TITLE, :path => index_file }]

  Nokogiri::HTML(open(index_file)).css("#bookcontents > ol > li > b > a").each do |chapter|
    pages << {
      :section => nil,
      :title => chapter.content,
      :path => File.join(src_dir, "book",chapter.attributes["href"])
    }
    chapter.parent.parent.search("ol/li/a").each do |section|
      pages << {
        :section => chapter.content,
        :title => section.content,
        :path => File.join(src_dir, "book", section.attributes["href"])
      }
    end
  end
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

    images << { :path => path, :dir => tokens.join(File::SEPARATOR)}
  end

  images
end

def get_styles(src_dir)
  [{ :path => "guide.css", :dir => src_dir}]
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
  src_dir = File.dirname(__FILE__)

  pages = get_pages(src_dir)
  images = get_images(src_dir)
  styles = get_styles(src_dir)

  epub = EeePub.make do
    title       DOC_TITLE
    creator     'why the lucky stiff'
    publisher   'why the lucky stiff'
    date        Time.now.strftime('%Y-%m-%d')
    identifier  'http://mislav.uniqpath.com/poignant-guide/book/', :scheme => 'URL'
    uid         'http://mislav.uniqpath.com/poignant-guide/book/'

    files pages + images + styles
    nav get_nav(pages)
  end

  epub.save('./poignant-guide.epub')
end
