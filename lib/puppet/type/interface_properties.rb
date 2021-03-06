#
# Copyright (c) 2013, 2016, Oracle and/or its affiliates. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

Puppet::Type.newtype(:interface_properties) do
  @doc = "Manage Oracle Solaris interface properties
      Protocol must be defined either at the interface/resource name or in
      the properties hash.

        Preferred:
        name: net0
        Properties:
        A complex hash of proto => { property => value },...
        {
          'ipv4' => { 'mtu' => '1776' },
          'ipv6' => { 'mtu' => '2048' },
        }

        Old Syntax:
        name: net0/ipv4
        Properties:
        A hash of property => value when Interface defines protocol
        { 'mtu' => '1776' }
  "

  ensurable do
    # remove the ability to specify :absent.  New values must be set.
    newvalue(:present) do
      # Do nothing
    end
    newvalue(:absent) do
      # We can only ensure synchronization
      fail "Interface properties cannot be removed"
    end
  end

  newparam(:name) do
    desc "The name of the interface"
    newvalues(/^[a-z_0-9]+[0-9]+(?:\/ipv[46]?)?$/)
    isnamevar

    validate do |value|
      unless (3..16).cover? value.split('/')[0].length
        fail "Invalid interface '#{value}' must be 3-16 characters"
      end
      unless /^[a-z_0-9]+[0-9]+(?:\/ipv[46]?)?$/ =~ value
        fail "Invalid interface name '#{value}' must match a-z _ 0-9"
      end
    end
  end

  newparam(:temporary) do
    desc "Optional parameter that specifies changes to the interface are
              temporary.  Changes last until the next reboot."
    newvalues(:true, :false)
  end

  newproperty(:properties) do
    desc "A hash table of proto/propname => propvalue entries to apply to the
              interface OR a complex hash of
              { proto => { propname => propvalue },... }
              Values are assigned as '='; list properties must be fully
              specified.  If proto is absent the protocol must be defined
              in the interface name. For proto 'ip' only the 'standby'
              property can be managed.
              See ipadm(8)"

    def insync?(is)
      # There will almost always be more properties on the system than
      # defined in the resource. Make sure the properties in the resource
      # are insync
      should.each_pair do |proto,hsh|
        return false unless is.key?(proto)
        hsh.each_pair do |key,value|
          # Stop after the first out of sync property
          return false unless property_matches?(is[proto][key],value)
        end
      end
      true
    end

    munge do |value|
      # If the supplied syntax isn't a hash of protocol options
      # reformat the value to that format
      if (value.keys & ["ip","ipv4","ipv6"]).empty?
        intf, proto = resource[:name].split('/')
        resource[:name] = intf
        value = { proto => value }
      end
      return value
    end
  end
  autorequire(:ip_interface) do
    children = catalog.resources.select do |resource|
      resource.type == :ip_interface &&
        self[:name].split('/').include?(resource[:name])
    end
    children.each.collect do |child|
      child[:name]
    end
  end
end
