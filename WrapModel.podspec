Pod::Spec.new do |s|

s.name = "WrapModel"
s.summary = "WrapModel is a data model class providing access to JSON formatted model data in string or dictionary form."
s.version = "1.0.3"

# Requirements
s.platform = :ios
s.ios.deployment_target = '10.0'
s.requires_arc = true
s.swift_version = '4.2'

s.license = { :type => "MIT", :file => "LICENSE" }
s.author = { "Ken Worley" => "ken@1stdibs.com" }

s.homepage = "https://github.com/1stdibs/WrapModel"
s.source = { :git => "https://github.com/1stdibs/WrapModel.git", :tag => s.version.to_s }

# Dependencies
# none currently

s.source_files = 'WrapModel/*.{swift}'

end

