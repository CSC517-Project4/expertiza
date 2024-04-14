puts "File.exist?(./../../spec/test_folder/example_view.html.erb) " + File.exist?("./../../spec/test_folder/example_view.html.erb").to_s

require 'yaml'

class ViewTranslationSubstitutor
  BLACKLIST = "([a-zA-Z0-9\\._]+|[\"\\'])?".freeze

  def substitute(locale)
    puts "IN SUBSTITUTE"
    stats = {}
    locale.each { |dir_name, view_hash| stats[dir_name] = process_directory(dir_name, view_hash) }
    puts "Translation Statistics:"
    puts stats.to_yaml
    File.open("translation_stats#{Time.now}.yml", 'w') { |file| file.write(stats.to_yaml) }
  end

  private

  def process_directory(dir_name, view_hash)
    puts "IN PROCESS_DIRECTORY"
    dir_stats = {}
    view_hash.each { |view_name, translations| dir_stats[view_name] = process_view(dir_name, view_name, translations) }
    dir_stats
  end

  def process_view(directory_name, view_name, translations)
    path = "./#{directory_name}/#{view_name}.html.erb"
    puts "IN PROCESS_VIEW: path is #{path}"

    unless File.exist?(path)
      path = "./#{directory_name}/_#{view_name}.html.erb"

      return '<file not found>' unless File.exist?(path)
    end

    view_stats = {}

    contents = File.open(path, 'w') { |file| file.read } || ''

    translations.each { |key, val| view_stats[key], contents = process_translation(contents, key, val) }
    File.open(path, 'w') { |f| f.write contents }

    view_stats
  end

  def process_translation(contents, key, val)
    puts "IN PROCESS_TRANSLATION, contents, key, val: #{contents}, #{key}, #{val}"
    replacements = []
    skips = []
    resume_index = 0
    while resume_index < contents.length
      match_data = contents[resume_index, contents.length].match(/#{BLACKLIST}(\s+)?(#{Regexp.escape(val)})(\s+)?#{BLACKLIST}/)
      break if match_data.nil?

      match_begin = resume_index + match_data.begin(0)
      match_end = resume_index + match_data.end(0)
      matched_text = match_data[0]
      black_start = match_data[1]
      white_start = match_data[2]
      white_end = match_data[4]
      black_end = match_data[5]

      puts "matched_text = #{match_data[0]} \
        black_start = #{match_data[1]} \
        white_start = #{match_data[2]} \
        match = #{match_data[3]} \
        white_end = #{match_data[4]} \
        black_end = #{match_data[5]}"

      if black_start == black_end && (black_start.nil? || %W[\" '].include?(black_start))
        t_call = black_start.nil? ? "#{key}" : "#{key}"
        replacement = "#{white_start}#{t_call}#{white_end}"
        replacements += [contents[match_begin, matched_text.length]]
        contents[match_begin, matched_text.length] = replacement
        resume_index = match_begin + replacement.length
        puts "replacements: " + replacements.to_s
      else
        resume_index = match_end
        skips += [matched_text]
        puts "skips: " + skips.to_s
      end
    end
    translation_stats = {}
    translation_stats['replacements'] = replacements unless replacements.empty?
    translation_stats['skips'] = skips unless skips.empty?
    translation_stats = '<unmatched>' if translation_stats == {}

    puts "translation_stats: " + translation_stats.to_s
    puts "contents: " + contents.to_s

    [translation_stats, contents]
  end
end

# locale = YAML.load_file('../../config/locales/en_US.yml')['en_US']
# locale = {
#   'student_task' => {
#     'publishing_rights' => locale['student_task']['publishing_rights']
#   }
# }
# ViewTranslationSubstitutor.new.substitute(locale)
