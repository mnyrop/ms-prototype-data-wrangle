require 'json'

page_paths = Dir.glob("./data/out/pages/*.json")
outpath = "./data/out/deduped_pages.json"

pages = page_paths.map do |path|
  JSON.parse(File.read(path))
end

# write pages to file
File.open(outpath, "w") do |f|
  f.write(JSON.pretty_generate pages)
end

afiles = JSON.parse(File.read('./data/out/afiles.json'))
g3s = JSON.parse(File.read('./data/out/g325as.json'))

# detect dupliacte ids in afiles
ids = afiles.map { |afile| afile['id'] }
dups = ids.select { |id| ids.count(id) > 1 }.uniq
puts "dups: #{dups}"

ids = g3s.map { |g| g['id'] }
dups = ids.select { |id| ids.count(id) > 1 }.uniq
puts "dups: #{dups}"