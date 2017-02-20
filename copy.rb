require 'psych'
require 'erubis'

src_root = ARGV[0]
dest_root = ARGV[1]
pairs = ARGV[2..-1]

def tempate_file (src, dest, pairs)
	puts src
	eruby = Erubis::Eruby.new(File.read(src))
	ctx = {}
	pairs.each do | p |
	  elements = p.split('=')
	  if elements.length == 2
	    ctx[elements[0]] = elements[1]
	  end
	end
	open(dest, "w") { |f| f.puts eruby.evaluate(ctx) }
end

if !File.directory?(src_root)
	if !File.directory?(File.dirname(dest_root))
		Dir.mkdir File.dirname(dest_root)
	end
	tempate_file(src_root, dest_root, pairs)
else
	Dir.glob("#{src_root}/**/*").each do |src|
		puts src
		dest = "#{dest_root}#{src[src_root.length..-1]}"
		if File.directory?(src)
			begin
				Dir.mkdir dest
			rescue
			end
		else
			if ! File.directory?(File.dirname(dest))
				Dir.mkdir File.dirname(dest)
			end
			if File.extname(src).eql?(".jar")
				open(dest, "wb") { |f| f.puts File.binread(src) }
			else
				tempate_file(src, dest, pairs)
			end
		end
	end
end

