require 'spec_helper'

RSpec.describe 'Interpolate' do

  def interpolate(s)
    AutoStacker24::Preprocessor.interpolate(s)
  end

  def join(*args)
    {'Fn::Join' => ['', args]}
  end

  it 'can handle empty strings' do
    expect(interpolate('')).to eq('')
  end

  it 'does not interpolate strings without AT' do
    expect(interpolate('hullebulle')).to eq('hullebulle')
  end

  it 'does not interpolate []' do
    expect(interpolate('hullebulle[bla]')).to eq('hullebulle[bla]')
  end

  it 'does not interpolate ::' do
    expect(interpolate('hullebulle::bla')).to eq('hullebulle::bla')
  end

  it 'does not interpolate .' do
    expect(interpolate('hullebulle.bla')).to eq('hullebulle.bla')
  end

  it 'escapes AT' do
    expect(interpolate('hullebulle@@bla.com')).to eq('hullebulle@bla.com')
  end

  it 'escapes AT everywhere' do
    expect(interpolate('@@hullebulle@@bla.com@@')).to eq('@hullebulle@bla.com@')
  end

  it '@ does escape only @' do
    expect(interpolate('@.@[@:@@.[:')).to eq('@.@[@:@.[:')
  end

  it 'replaces Param' do
    expect(interpolate('@Param')).to eq({'Ref' => 'Param'})
  end

  it 'replaces AWS::Param' do
    expect(interpolate('@AWS::Param')).to eq({'Ref' => 'AWS::Param'})
  end

  it 'joins multiple parts' do
    expect(interpolate('bla @Param-blub')).to eq(join('bla ', {'Ref' => 'Param'}, '-blub'))
  end

  it 'expression stops at "@"' do
    expect(interpolate('@Param@::text')).to eq(join({'Ref' => 'Param'}, '@::text'))
  end

  it 'is greedy if not embedded in curlies' do
    expect(interpolate('@Param.domain.tld')).to eq({'Fn::GetAtt' => ['Param', 'domain.tld']})
  end

  it 'stops expression at curly brace' do
    expect(interpolate('@{Param}.domain.tld')).to eq(join({'Ref'=>'Param'}, '.domain.tld'))
  end

  it 'is greedy if not embedded in curlies, embedded' do
    expect(interpolate('bla @Param.bla bla')).to eq(join('bla ', {'Fn::GetAtt' => ['Param', 'bla']}, ' bla'))
  end

  it 'stops expression at curly brace, embedded' do
    expect(interpolate('bla @{Param}.bla bla')).to eq(join('bla ', {'Ref'=>'Param'}, '.bla bla'))
  end

  it 'dot does generate Fn::GetAtt in curly' do
    expect(interpolate('@{Param.attr1.attr2}.domain.tld')).to eq(
      join({'Fn::GetAtt' => ['Param', 'attr1.attr2']}, '.domain.tld'))
  end

  it 'dot does generate Fn::GetAtt in curly, embedded' do
    expect(interpolate('bla @{Param.attr}bla bla')).to eq(
      join('bla ', {'Fn::GetAtt' => ['Param', 'attr']}, 'bla bla'))
  end

  it '[top,second] generates Fn::FindInMap' do
    expect(interpolate('@MyMap[Top, Second]')).to eq({'Fn::FindInMap' => ['MyMap', 'Top', 'Second']})
  end

  it 'generates Fn::FindInMap from curly brace expressions' do
    expect(interpolate('@{MyMap[Top, Second]}')).to eq({'Fn::FindInMap' => ['MyMap', 'Top', 'Second']})
  end

  it '[top,second] generates Fn::FindInMap embedded' do
    expect(interpolate('@MyMap[  Top  ,Second  ]bla')).to eq(join({'Fn::FindInMap' => ['MyMap', 'Top', 'Second']}, 'bla'))
  end

  it '@Env[second] generates Fn::FindInMap by convention' do
    expect(interpolate('@{Env[Second]}')).to eq({'Fn::FindInMap' => ['EnvMap', {'Ref' => 'Env'}, 'Second']})
  end

  it '@Map[@Top, @Second] has simple expressions as keys' do
    expect(interpolate('@Map[@Top, @Second]')).to eq({'Fn::FindInMap' => ['Map', {'Ref' => 'Top'}, {'Ref' => 'Second'}]})
  end

  it '@Map[@TopMap[@i2, second], @Second] generates nested Fn::FindInMap' do
    nested_find_in_map = {
        'Fn::FindInMap' => [
            'Map',
            {'Fn::FindInMap' => ['SubMap', {'Ref' => 'i2'}, 'second']},
            {'Ref' => 'Second'}
        ]
    }
    expect(interpolate('@Map[@SubMap[@i2, second], @Second]')).to eq(nested_find_in_map)
  end

  it 'ignores whitespace in brackets' do
    find_in_map = {
        'Fn::FindInMap' => [
            'm1',
            {'Fn::FindInMap' => ['m2', {'Ref' => 'i'}, 'j']},
            {'Ref' => 'k'}
        ]
    }
    expect(interpolate('@m1[  @m2[ @i , j ],  @k  ]')).to eq(find_in_map)
  end

  it 'includes files with @{file} and interpolates content' do
    interpolated = join("bla\n#!/bin/bash\n\necho \"", {'Ref' => 'Version'}, "\"\n\nblub")
    expect(interpolate("bla\n@{file://./spec/examples/script.sh}\nblub")).to eq(interpolated)
  end

  it 'includes files with @file and interpolates content' do
    interpolated = join("bla\n#!/bin/bash\n\necho \"", {'Ref' => 'Version'}, "\"\n\nblub")
    expect(interpolate("bla\n@file://./spec/examples/script.sh\nblub")).to eq(interpolated)
  end

  it '@{file} is still interpolated as a ref' do
    expect(interpolate('@{file}')).to eq({'Ref' => 'file'})
  end

  it '@file is still interpolated as a ref' do
    expect(interpolate('@file')).to eq({'Ref' => 'file'})
  end

  it 'can use curly braces to remove ambiguity' do
    expect(interpolate('@{subdomain}.example.com.')).to eq({'Fn::Join' => ['', [{'Ref' => 'subdomain'}, '.example.com.']]})
  end
end
