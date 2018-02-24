function! SubnetQuickSearch()
python << PYEND
"""
    Takes a string from what is currently highlighted in vim, generates a
    regeular expression to match all the ip addresses in that subnet, and runs
    a search using that regular expression.
    Requires: python 2.7
    Updated: Various uses of str and unicode functions to compensate for unicode
             issues in mainline ipaddress module

"""
import sys, re
import ipaddress
import vim
from pprint import pprint
from collections import defaultdict

@property
def _octets(self):
    """
        returns a list the octets in an ip address
    """
    # compensate for unicode issue in mainline ipaddress module by mapping
    # str to the list of octets
    # this will be used to build a regex string - unicode doesn't work.
    octets = map(str, list(self.exploded.replace('/', '.').split('.')) )
    if len(octets) > 4:
        return octets[:-1]
    else:
        return octets
# all ipaddress type inherit this method.
# makes going through the octets in an ip
# address easier
ipaddress._IPAddressBase.octets = _octets

def bracket_expr(_list):
    """
        takes:
                a list of numbers as single characters
        returns:
                a bracketed expression to match the numbers in the list
        NOTE: If a single digit is passed, it is returned
    """
    if len(_list) == 1:
        return _list[0]
    elif len(_list) == 2:
        return '[' + _list[0] + _list[1] + ']'
    else:
        return '[' + min(_list) + '-' + max(_list) + ']'

def str2list(localstring):
    """
        Takes: the result of int(list)
        Returns: the original list
    """
    localstring = str(localstring)
    returned_list = []
    for part in localstring.split(','):
        returned_list.append(re.sub("'|\]|\[| ", '', part))
    return returned_list

def groupbyvalue(_key, _dict):
    """
        Takes:  _key character: determines if this is single digit part of a range
                _dict dict: dict of lists
        returns: a datastructure whereby the keys of the dict are
                grouped by the values or lists
        example:
              {'0': ['9', '8', '7', '6', '5', '4', '3', '2', '1'],
               '1': ['9', '8', '7', '6', '5', '4', '3', '2', '1', '0'],
               '2': ['9', '8', '7', '6', '5', '4', '3', '2', '1', '0']},
        returns:
                [(['9', '8', '7', '6', '5', '4', '3', '2', '1'], ['0']),
                 (['9', '8', '7', '6', '5', '4', '3', '2', '1', '0'], ['1', '2'])]
    """
    v = defaultdict(list)
    for key,value in sorted(_dict.iteritems()):
        if _key != '0':
            v[str(value)].append(key)
        else:
            if key != '0':
                v[str(value)].append(key)
    _list = []
    if _key == '0':
        try:
            _list.append(((_dict['0']), ['0']))
        except:
            pass
    for key, value in  v.items():
        _list.append((str2list(key), value))
    return _list


def group_octets(network):
    """
        take: an ip network address: '10.9.8.0/24'
        returns: a list of 4 lists, each sublist containing a list of strings representing
                 the sequence of numbers of an octet in a network range
                
    """
    if type(network) is not ipaddress.IPv4Network:
        network = ipaddress.ip_network(network)
    _octets = []
    for a in range(4):
        _octets.append([])
    for address in [network.network_address] + list(network.hosts()) + [network.broadcast_address]:
        for octet_list, _octet in enumerate(address.octets):
            if _octet not in _octets[octet_list]:
                _octets[octet_list].append(_octet)
    return _octets

def build_dd(lines):
    """
        takes: a list comprised of strings representing numbers three digits long
        Returns: a dict of dicts of lists
    """
    dd = {}
    dd['0'] = {}
    for row in reversed(lines):
        if len(row) == 3:
            if row[0] not in dd:
                dd[row[0]] = {}
            if row[1] not in dd[row[0]]:
                dd[row[0]].update({row[1]:[]})
            dd[row[0]][row[1]].append(row[2])
        elif len(row) == 2:
            if row[0] not in dd['0']:
                dd['0'].update({row[0]:[]})
            if row[1] not in dd['0'][row[0]]:
                dd['0'][row[0]].append(row[1])
        elif len(row) == 1: # single digit number
            if '0' not in dd['0']:
                dd['0'].update({'0':[]})
            if row[0] not in dd['0']['0']:
                dd['0']['0'].append(row[0])
    return dd


def dd2Regex(dd, anchor1='\.', anchor2='( |$|[^0-9])'):
    """
        takes: a dict of dicts of lists from build_dd - contents of an octet
        returns: a regular expression match only the contents of the list
        NOTE: vim is limited to 10 groups total
    """
    regex = '' 
    for key in sorted(dd.keys()):
        if key == '0':
            l = len(groupbyvalue(key, dd['0']))
            for row_num, row in enumerate(groupbyvalue(key, dd['0'])):
                if row[1][0] == '0':
                    regex += anchor1 + bracket_expr(row[0]) + anchor2
                else:
                    regex += anchor1 + bracket_expr(row[1]) + bracket_expr(row[0]) + anchor2
                if l > 1 and row_num + 1 < l:
                    regex += '|'
            if l > 0:
                regex += '|'
        else:
            for row_num, row in enumerate(groupbyvalue(key, dd[key])):
                regex += anchor1 + key + bracket_expr(row[1]) + bracket_expr(row[0]) + anchor2
                regex += '|'
    if regex[-1] == '|':
        regex = regex[:-1]
    return regex


def Network_Regex(network):
    """
        Takes: a CIDR network either as a string or IPv4Network
        Returns: a regex matching the addresses falling withing that network
    """
    if type(network) is not ipaddress.IPv4Network:
        network = unicode(network)
        network = ipaddress.ip_network(network)
    regex = '\\'
    regex += 'v'
    for row_num, octet in enumerate(group_octets(network)):
        if row_num == 3:
            regex += '(' + dd2Regex(build_dd(octet), anchor1='') + ')'
        else:
            regex += '(' + dd2Regex(build_dd(octet), anchor1='', anchor2='\.') + ')'
    return regex

def input(message = 'Subnet'):
  vim.command('call inputsave()')
  vim.command("let Subnet = input('" + message + ": ')")
  vim.command('call inputrestore()')
  return vim.eval('user_input')

if __name__ == "__main__":

    vim.command("let Subnet = @*")
    i = vim.eval('Subnet')
    if len(i.split()) == 2 or len(i.split("/")) == 2:
        # compensate for arbitrary unicode error in mainline ipaddress module
        i = unicode(i) 
        if "/" not in i:
            try:
                p = ipaddress.ip_address(i.split()[0])
            except ValueError:
                print i, "doesn't seem like an IP address"
                exit()
            try:
                subnet = ipaddress.ip_interface(unicode(p) + '/' + unicode(p._make_netmask(i.split()[1])[1])).network
            except IndexError:
                print i, "doesn't look like a good subnet address"
                exit()
            except ValueError:
                print i, "Doesn't look like a good subnet address"
                exit()
        elif "/" in i:
            try:
                subnet = ipaddress.ip_interface(i).network
            except IndexError:
                print i, "Doesn't look like a good subnet address"
                exit()
    subnet_match = Network_Regex(subnet)
    # set the register for the last search to this search
    vim.command('let @/ = ' + "'" + subnet_match + "'")
    # run this search
    vim.command('/' + subnet_match)
PYEND
endfunc

" F4 is used here arbitrarily.  The extra '/' is there so the search is
" highlighted without more user keystrokes.
noremap <F10> :call SubnetQuickSearch()<CR>/<CR>
inoremap <F10> <ESC>:call SubnetQuickSearch()<CR>/<CR>i

