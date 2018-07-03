Dir[File.dirname(__FILE__) + '/stripe/*.rb'].each {|file| require_dependency file }
