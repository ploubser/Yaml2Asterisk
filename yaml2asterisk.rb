#! /usr/bin/ruby

begin
  require 'rubygems'
  require 'yaml'
  require 'optparse'
  require 'rgl/adjacency'
  require 'rgl/dot'
  require 'lib/yaml2asterisk'
  require 'pp'
rescue LoadError => e
  puts "Missing required gem or library - #{e.to_s.gsub(/.*-- /, "")}"
  exit!
end

include Yaml2Asterisk

#Generate Asterisk menus from a yaml file.
#Example yaml menu can be found in sample-menu.yaml
@nodes = {}
@output = STDOUT
@extension = "NO-NAME"
@path = Dir.pwd
@root = true
@first = ""
@graph = ""
@exten = "s"

OptionParser.new do |opts|
  opts.banner = "Usage: yaml2asterisk.rb [options]"

  opts.on("-i", "--input [FILE]", "Input file") do |f|
    @config ||= YAML::load(File.read(f))
  end

  opts.on("-o", "--output [FILE]", "Output file") do |f|
    @output = File.open(f, "w")
  end

  opts.on("-n", "--name [STRING]", "Extension name") do |f|
    @extension = f
  end

  opts.on("-p", "--path [DIR]", "Path to sound files") do |f|
    @path = f.gsub(/\/$/, "")
  end

  opts.on("-g", "--graph [STRING]", "Generate a graph of menu as [STRING].dot") do |f|
    @graph = f
  end
end.parse!

begin
  @config ||= YAML.load(File.read("menus/sample-menu.yaml"))
rescue Exception => e
  puts "Error - No menu given and default menu, menus/sample-menu.yaml,  does not exist."
  exit!
end

create_nodes(@config)

unless @graph == ""
  draw_graph
end

@output.puts "[#{@extension}]"
@output.puts "exten => s,1,Background(#{@path}/#{"1"})"

#Generate Asterisk extension from nodes hash
@nodes.sort{|a,b| a[0].to_s.gsub("_", "") <=> b[0].to_s.gsub("_", "")}.each do |node|
  ob = node[1]

  unless @root || ob.type =~ /command|sound/
    @output.puts "\n[#{@extension}-#{ob.name}]"
  end

  if ob.type == "goto"
    @first = true
    if ob.points_at.include?("_hangup()")
      @output.puts "exten => s,1,Set(PLAYED=0)"
      ob.points_at.each do |tmp|
        if tmp =~ /_log\((.)\)/
          @output.puts "exten => s,n,AGI(queue_selection.agi|#{$1})"
          ob.points_at.delete tmp
        end
      end
      @output.puts "exten => s,n,Goto(100,1)"
      @exten = "100"
    else
      ob.points_at.each do |tmp|
        if tmp =~ /_log\((.)\)/
          @output.puts "exten => s,1,AGI(queue_selection.agi|#{$1})"
          @first = false
          ob.points_at.delete tmp
        end
      end

      @exten = "s"
    end

    if ob.points_at.include?("_answer()")
      @output.puts "exten => #{@exten},#{extension_pos},Set(GLOBAL(TELCO)=\"\")"
      @first = false
    end

    ob.points_at.each do |play|
      unless @nodes[play].type == "command"
        @output.puts "exten => #{@exten},#{extension_pos},Background(#{@path}/#{play.gsub("_","")})"
        @first = false
      else
        if ob.points_at.include?("_hangup()")
          @output.puts "exten => 100,n,Set(PLAYED=$[${PLAYED} + 1])"
          @output.puts "exten => 100,n,Waitexten(2)"
          @output.puts "exten => 100,n,Gotoif($[\"${PLAYED}\" = \"2\"]?s-HANGUP,1:100,1)"
        end
        @output.puts "exten => #{@nodes[play].name == "_hangup()" ? "s-HANGUP" : @exten},#{@nodes[play].name == "_hangup()" ? "1" : extension_pos},
		  #{parse_command(@nodes[play].name)}"
        @first = false
      end
    end

    if ob.require_input == true
	  @output.puts "exten => #{@exten},n,WaitExten(5)"
      @output.puts "exten => t,1,Goto(s,1)"
      @output.puts "exten => i,1,Goto(s,1)"

      ob.points_at.each_with_index do |node,i|
        unless @nodes[node].type == "command"
          @output.puts "exten => #{i+1},1,Goto(#{@extension}-#{@nodes[node].name},s,1)"
        else
          @output.puts "exten => #{i+1},1,#{parse_command(@nodes[node].name)}"
        end
      end
    end

  end
  @root = false
end
