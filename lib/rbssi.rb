require 'rubygems'
require 'hpricot'
require 'net/http'
require 'uri'

SSICommands = {
  :include => 'ssi_include',
  :echo => 'ssi_echo',
  :set => 'ssi_set',
  :block => 'ssi_block_open',
  :endblock => 'ssi_block_close'
}

def ssi_block_open(options,vars)
end

def ssi_block_close(options,vars)
end

def ssi_include(options,vars)
  puts "call include: #{options.inspect}"
  if options['file']
    File.read(options['file'])
  elsif options['virtual']
    url = options['virtual']
    url = "http://#{SSI_HOST}#{url}" if SSI_HOST
    puts "SSI: #{url}"
    #Curl::Easy.http_get(url){|c| c.follow_location = true }.body_str

    uri = URI.parse(url)
    res = Net::HTTP.start(uri.host, uri.port) {|http| http.get(uri.path) }
    res.body
  end
end

def ssi_echo(options,vars)
  var = options['var']
  if vars[var]
    vars[var]
  else
    options['default']
  end
end

def ssi_set(options,vars)
  var = options['var']
  value = options['value']
  vars[var] = value
  ""
end

def ssi_parser(ssi,vars)
  ssi.gsub!(/-->.*$/,'') # make sure we remove any trailing comment string...
  cmd = ssi.scan(/\w+/).first
  options = {}
  kvs = ssi.gsub(/\w+\s/,'').split(/\s/).map{|ks| ks.split('=') }
  puts kvs.inspect
  kvs.each {|k,v| options[k] = v.strip.gsub(/^"/,'').gsub(/"$/,'').strip }
#  kvs = ssi.gsub(/\w+\s/,'').split('=').map{|kv| kv.strip.gsub(/^"/,'').gsub(/"$/,'').strip }
#  kvs.each_with_index {|kv,i| options[kv] = kvs[i+1] if i % 2 == 0 }
  send(SSICommands[cmd.to_sym],options,vars)
end

#
# scan for ssi commands
#
def ssi(content)
  
  vars = {}
  outmap = {}
  # store the original ssi command line and it's parsed command

  content.scan(/(<!--#(.*)-->)/) do|m|
    outmap[m.first] = m.last.strip # store for processing later
  end

  # now we have each ssi command string
  # and the parsed form, loop over each ssi command string
  # and process
  outmap.each do|k,v|
    content.sub!(k,ssi_parser(v,vars))
  end

  content
end

if $0 == __FILE__
  require 'test/unit'

  class SSITest < Test::Unit::TestCase
    def test_include
      out = ssi(%{<!--# include file="header.html" -->
    <div id="stage">
<!--# include virtual="http://www.google.com/" -->
    </div>
<!--# include file="footer.html" -->})
      assert_match(/^<!DOCTYPE html/,out)
      assert_match(/google/,out)
      assert_match(/<\/html>$/,out)
    end
    def test_echo
      out = ssi(%{<!--# echo var="foo" default="no" -->
    <div id="stage">
    </div>
<!--# include file="footer.html" -->})
      assert_match(/no/,out)
      assert_match(/<\/html>$/,out)
    end

    def test_set
      out = ssi(%{<!--# echo var="foo" default="no" -->
    <div id="stage">
    </div>
<!--# set var="foo" value="bar" -->
<!--# echo var="foo" -->})
      assert_match(/no/,out)
      assert_match(/bar/,out)
    end

  end
end
