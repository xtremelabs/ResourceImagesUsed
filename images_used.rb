#!/usr/bin/ruby

if ARGV.length < 1
  puts "tell me which dir..."
  exit 1
end

unless File.directory?(ARGV.last)
  puts "please provide a valid directory..."
  exit 1
end

verbose = ARGV.include?("-v")
exclude_comments = ARGV.include?("-c")
generate_delete_script = ARGV.include?("-s")

class Array
  def only_duplicates
    duplicates = []
    self.each {|each| duplicates << each if self.count(each) > 1}
    duplicates
  end
end

class DirParser
  attr_accessor :code, :imgs

  def initialize(file=".")
    @files = []
    @code = []
    @imgs = []
    @img_exts = ["png","jpg","jpeg"]
    @code_exts = ["m","h","xib","c","cc","cpp","html","xml","erb","rb","plist"]

    @files << file

    get_files
  end

  def process_file(f)
    if "." == f || ".." == f
      #do nothing
    elsif File.directory?(f)
      @files = Dir.entries(f).select{|i| i != "." && i != ".." }.map{ |p| "#{f}/#{p}" } + @files
    else
      #is file
      ext = f.split(".").last
      if @img_exts.include?(ext)
        f["@2x."] = "." unless f.index("@2x.").nil?
        @imgs << f
      elsif @code_exts.include?(ext)
        @code << f
      end
    end
  end

  def get_files
    while @files.count > 0
      f = @files.pop
      process_file(f)
    end
  end

end

p = DirParser.new(ARGV.last.split("/").join("/"))

def hor_line
  puts "--------------------------------------------------"
end

if verbose
  hor_line
  puts "Code Files: (#{p.code.count} Files)"
  hor_line
  puts p.code.join("\n")
  puts "\n"
  hor_line
  puts "Resources: (#{p.imgs.count} Files)"
  hor_line
  puts p.imgs.join("\n")
end

imgs = p.imgs.map{ |i| i.split("/").last }.uniq
not_used = imgs

usages = {}

p.code.each do |c|
  f = File.open(c,"r")
  contents = f.readlines

  if exclude_comments
    #remove comments
    comment_ext = ["m","c","cpp","h","cc"]

    if comment_ext.include?( c.split(".").last )
      isInMultiLineComment = false
      (0..(contents.length - 1)).each do |i|
        line = contents[i]

        unless isInMultiLineComment
          matches = line.scan(/^(.*)(\/\/)(.*)$/)
          unless matches.empty?
            contents[i] = matches.first.first
          end

          line = contents[i]
          matches = line.scan(/^(.*)(\/\*)(.*)$/)
          unless matches.empty?
            contents[i] = matches.first.first
            isInMultiLineComment = true
          end
        else
          matches = line.scan(/^(.*)(\*\/)(.*)$/)
          if matches.empty?
            contents[i] = ""
          else
            contents[i] = matches.first.last
            isInMultiLineComment = false
          end
        end
      end
    end
  end

  contents.each do |l|
    words = l.split

    intersect = []
    words.each { |w|
      imgs.each { |i|
        name_of_image = i.index(".").nil? ? i : i.split(".")[0]

        unless w.index(i).nil? && (l.scan(/^(.*)(imageNamed:@\"#{name_of_image}\")(.*)$/).empty?)
          intersect << i
        end
      }
    }
    intersect.uniq!

    intersect.each do |image|
      occurence = {:line => l, :resource => image, :line_number => contents.index(l)}
      not_used.delete(image)

      if usages[image].nil?
        usages[image] = [occurence]
      else
        usages[image] << occurence
      end
    end
  end
end

puts "\n" if verbose
hor_line
puts "Resources not used: (#{not_used.count} resources)"
hor_line
puts not_used.join("\n")
puts "\n"

if verbose
  hor_line
  puts "Resources used: (#{usages.count} resources)"
  hor_line
  puts usages.keys.join("\n")
end


if verbose
  dup_imgs = p.imgs.map{ |i| i.split("/").last }.only_duplicates.uniq
  puts "\n"
  hor_line
  puts "Duplicate Resources: (#{dup_imgs.count} duplicates)"
  hor_line
  puts dup_imgs.join("\n")
  puts "\n"
end

if generate_delete_script
  f = File.new("./delete.sh","w")
  abs_path = File.expand_path(ARGV.last)
  not_used.each do |i|
    resource_path = p.imgs.drop_while{ |path| path.split("/").last != i }.first
    f << "rm #{File.expand_path(resource_path)}\n"
  end
  f.close
  `chmod a+x delete.sh`
end
