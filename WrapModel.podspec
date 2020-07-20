Pod::Spec.new do |s|

s.name = "WrapModel"
s.summary = "WrapModel is a data model class providing access to JSON formatted model data in string or dictionary form."
s.version = "1.3.2"

# Requirements
s.platform = :ios
s.ios.deployment_target = '11.0'
s.requires_arc = true
s.swift_versions = ['4.2', '5.0', '5.1']

s.license = { :type => "MIT", :file => "LICENSE" }
s.author = { "Ken Worley" => "ken@1stdibs.com" }

s.homepage = "https://github.com/1stdibs/WrapModel"
s.source = { :git => "https://github.com/1stdibs/WrapModel.git", :tag => s.version.to_s }

# Dependencies
# none currently

s.source_files = 'WrapModel/*.{swift}'

end

