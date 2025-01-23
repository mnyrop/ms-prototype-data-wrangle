require 'csv'
require 'json'

IN_DIR              = './data/in'
OUT_DIR             = './data/out'
EXTRACTED_DATA_DIR  = './extracted-data/data'
OCR_DIR             = "#{EXTRACTED_DATA_DIR}/page_ocr"
NARA_FIELDS         = %w(LAST_NAME FIRST_NAME DOB SEX DOE POE COB PFCO DFO NATZ_DATE NATZ_LOCATION)

# GET LIST OF SUBSET ANUMBERS FOR WHICH TO COLLATE DATA FROM ACROSS DATA FILES
PROTOTYPE = CSV.open("#{IN_DIR}/prototype_list.csv", headers: :first_row).map(&:to_h)
ANUMBERS  = PROTOTYPE.map { |h| h['ANUMBER'] }

def deep_compact(hash)
  res_hash = hash.map do |key, value|
    value = deep_compact(value) if value.is_a?(Hash)

    value = nil if [{}, [], '', nil].include?(value)
    [key, value]
  end
  res_hash.to_h.compact
end

# OPEN  NARA CATALOG DATA, PLUCK SUBSET AND MERGE IN M/S AFILE DATA
NARA_AFILES = CSV.open("#{IN_DIR}/nara_catalog.csv", headers: :first_row).map(&:to_h)
@afiles = NARA_AFILES.map do |afile|
  is_wanted  = ANUMBERS.include?(afile['ANUMBER'])
  json_path  = "#{EXTRACTED_DATA_DIR}/afiles/#{afile['ANUMBER']}.json"
  next unless is_wanted and File.file?(json_path)

  afile.compact!
  ms_json = JSON.parse(File.read(json_path))
  NARA_FIELDS.each do |field| 
    next unless afile.key?(field)
    
    ms_json['fields'][field.downcase] = {} unless ms_json['fields'].key?(field.downcase)
    ms_json['fields'][field.downcase]['nara'] = afile.dig(field) 
  end
  deep_compact(ms_json)
end.compact

# EXPORT SUBSET AFILE DATA
puts "writing data for #{@afiles.count} afiles"
File.write("#{OUT_DIR}/afiles.json", JSON.pretty_generate(@afiles))

# PLUCK SUBSET PAGES FROM M/S PAGE DATA BY ANUMBER
@page_paths = ANUMBERS.map { |anum| Dir.glob("#{EXTRACTED_DATA_DIR}/pages/#{anum}_*.json") }.flatten.compact
@pages      = @page_paths.map do |path| 
  file = File.read(path).gsub('NaN', 'null')
  JSON.parse(file)
end

# ADD IN OCR TXT
@pages.map! do |page|
  @anum = page['id']
  @id = page['afile_id']
  page['id'] = @id 
  page['anumber'] = @anum

  ocr_path = "#{OCR_DIR}/#{page['id']}.txt"

  page['full_text'] = File.read(ocr_path) if File.file?(ocr_path)
  page['resources'].delete('ocr_exists')
  page.delete('afile_id')
  deep_compact(page)
end

# EXPORT SUBSET PAGE DATA
puts "writing data for #{@pages.count} pages"
File.write("#{OUT_DIR}/pages.json", JSON.pretty_generate(@pages))

# GET LIST OF SUBSET G325A FORMS + EXPORT
@g325as = @pages.select { |page| page.dig('fields', 'is_g325a') == true }
puts "writing data for #{@g325as.count} g325as"
File.write("#{OUT_DIR}/g325as.json", JSON.pretty_generate(@g325as))

# GET LIST OF SUBSET NATCERTS + EXPORT
@natcerts = @pages.select { |page| page.dig('fields', 'is_cert_naturalization') == true }
puts "writing data for #{@natcerts.count} natcerts"
File.write("#{OUT_DIR}/natcerts.json", JSON.pretty_generate(@natcerts))
