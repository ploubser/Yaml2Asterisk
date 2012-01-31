module Yaml2Asterisk
    #Node class is a representation of a single value in the yaml
    #file, determining type and another structural information
    #based on the yaml file's structure.

  class Node
    attr_accessor :type, :name, :require_input, :points_at, :plays, :id, :subtree

    def initialize(node, tree)

      @id = "#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}"
      @name = node
      findme(tree)

      if @name =~ /.*_$/
        @require_input = true
      else
        @require_input = false
      end

      unless @subtree.nil?
        @type = "goto"
      else
        if @name =~ /^_.*/
          @type = "command"
        else
          @type = "sound"
        end
      end

      @points_at = []

      unless @subtree.nil?
        @subtree.values.first.each do |subelement|
          if subelement.class == Hash
            @points_at << subelement.keys.first.to_s
          else
            @points_at << subelement.to_s
          end
        end
      else
        @points_at = []
      end

      @subtree = nil

    end

    #Display values of node internals
    def show
      puts "ID = #{@id}"
      puts "Node name = #{@name}"
      puts "Require's input = #{@require_input}"
      puts "Type = #{@type}"
      puts "Points at => #{@points_at.pretty_inspect}"
    end

    #Recursive method finds node's position in the yaml tree
    def findme(subtree)
      if subtree.class == Hash
        if subtree.keys.first.to_s == @name
          @subtree = subtree
        else
          subtree.values.first.each do |subelement|
            findme(subelement)
          end
        end
      end
    end
  end
end
