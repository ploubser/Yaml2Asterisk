module Yaml2Asterisk
  require "lib/node/node.rb"

  #Creates the node objects and stores them in a hash
  #by recursively stepping through the yaml tree.
  def create_nodes(subtree)
    if  subtree.class == Hash
      @nodes[subtree.keys.first.to_s] = Node.new(subtree.keys.first.to_s, subtree)
      subtree.values.first.each do |subelement|
        create_nodes(subelement)
      end unless subtree.class == String
    elsif subtree.class == NilClass
      return
    elsif subtree.class == Array
      subtree.values.first.each do |subelement|
        create_nodes(subelement)
      end
    elsif subtree.class == String
      @nodes[subtree] =  Node.new(subtree, subtree)
    end
  end

  #Helper determines command type.
  def parse_command(command)
    case command
    when /_set\((.*)=(.*)\)/
      return "Set(GLOBAL(#{$1})=\"-#{$2}\")"
    when /_jump\((.+)\)/
      return "Goto(#{$1},s,1)"
    when /_go\((.+)\)/
      return "Goto(#{@extension}#{$1=="1_"?"":("-" + $1)},s,1)"
    when /_agi\((.+)\)/
      return "AGI(#{$1})"
    when "_hangup()"
      return "Hangup()"
    when "_answer()"
      return "Goto(#{@extension.gsub("menu-","from-")},s,1})"
    end
  end

  #Helper determines node position
  def extension_pos
    if @first == true and  @root == false
      return "1"
    else
      return "n"
    end
  end

  #Draws a graph of the yaml file and outputs in dot format.
  def draw_graph
    dg = RGL::DOT::Digraph.new
    @nodes.sort{|a,b| a[0].to_s.gsub("_", "") <=> b[0].to_s.gsub("_", "")}.each do |node|
      if node[1].points_at.include?("_answer()")
        node[1].points_at.each do |point|
          dg << RGL::DOT::Node.new("name" => point.gsub("_", ""),
                                         "color" => "blue",
                                         "shape" => "diamond"
                                  ) unless point =~/^_.*/
        end
      elsif node[1].points_at.include?("_hangup()")
        node[1].points_at.each do |point|
          dg << RGL::DOT::Node.new("name" => point.gsub("_", ""),
                                         "color" => "red",
                                         "shape" => "box"
                                  ) unless point =~/^_.*/
        end
      elsif node[0] =~ /.*(\d)_/
        dg << RGL::DOT::Node.new("name" => node[0].gsub("_", ""),
                                     "color" => "green",
                                     "shape" => "triangle"
                                ) unless node[0] =~ /^_.*/
      elsif node[1].points_at.join(" ") =~ /.*_go\((.*)\).*|.*_jump\((.*)\)/
        if $2.nil?
          dg << RGL::DOT::Node.new("name" => node[0],
                                         "color" => "purple",
                                         "shape" => "hexagon")
          dg << RGL::DOT::DirectedEdge.new("to" => $1.gsub("_",""), "from" => node[0].gsub("_", ""))
        elsif $1.nil?
          name = $2.gsub("_","")
          dg << RGL::DOT::Node.new("name" => name,
                                         "color" => "purple",
                                         "shape" => "hexagon")
          dg << RGL::DOT::DirectedEdge.new("to" => name, "from" => node[0].gsub("_", ""))
        end
      end
      node[1].points_at.each_with_index do |edge,i|
        unless edge =~/^_.*/
          dg << RGL::DOT::DirectedEdge.new("to" => edge.gsub("_", ""), "from" => node[0].gsub("_", ""))
        end
      end
    end
    File.open("#{@graph}.dot", "w"){|f| f.puts dg.to_s}
    exit!
  end
end
