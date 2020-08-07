import sys, re, ipaddress
# import vim
from pprint import pprint
from collections import defaultdict
import code

@property
def _octets(self):
    """
        returns a list the octets in an ip address

        NOTE:
              fixed to compensate for 'exploded' returning a unicode object.
              These values are used later to build a regex string passed to
              vim.

    """
    octets = list(str(self.exploded).replace('/', '.').split('.'))
    if len(octets) > 4:
        return octets[:-1]
    else:
        return octets
# all ipaddress type inherit this method.
# makes going through the octets in an ip
# address easier
ipaddress._IPAddressBase.octets = _octets

def ip_address(ip):
    """
        Compensates for 'Did you pass in a bytes (str in Python 2) instead of a unicode object?'

    """
    return ipaddress.ip_address(str(ip))

def ip_network(ip):
    """
        Compensates for 'Did you pass in a bytes (str in Python 2) instead of a unicode object?'

    """
    return ipaddress.ip_network(str(ip))

def ip_interface(ip):
    """
        Compensates for 'Did you pass in a bytes (str in Python 2) instead of a unicode object?'

    """
    return ipaddress.ip_interface(str(ip))

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
        Meaning: Each tuple represents an the vertical position of a list of up to
                 three digits - the first element is the digit range and the second
                 element is the position.  Above vertical columns has digits 1-9,
                 and columns 1 and 2 have 0-9
    """
    v = defaultdict(list)
    for key,value in sorted(_dict.items()):
        if _key != '0':
            v[str(value)].append(key)
        else:
            if key != '0':
                v[str(value)].append(key)
    _list = []
    if _key == '0':
        try:
            _list.append(((_dict['0']), ['0']))
        except Exception as E:
            print(f"groupbyvalue got error '{E}' trying to append ({_dict}, {['0']})")
            raise
            pass
    for key, value in list(v.items()):
        _list.append((str2list(key), value))
    return _list


def group_octets(network):
    """
        take: an ip network address: '10.9.8.0/24'
        returns: a list of 4 lists, each sublist containing a list of strings representing
                 the sequence of numbers of an octet in a network range

    """
    if type(network) is not ipaddress.IPv4Network:
        network = ip_network(network)
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
        This function is meant to summarize vertical columns in a list containing
        strings of numbers up to three digits long.  The resulting dict is part of
        building a regular expression to match a the range of numbers in the list
        of lines.  The inner dict has keys for each digit in that position and what
        may follow that digit. The number of primary keys represents groups of
        dependencies. In the example of 0-127, '0' would be a dict expressing that
        each digit 0-9 can be follow by a 0-9.  '1' would be a dict expressing that
        digits '0' and '1' could be follow by 0-9, but '2' could only be followed
        by 0-7.  Thus a basic counting sequence is in the structure of the returned
        dict.
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
        elif len(row) == 1:  # single digit number
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
        network = ip_network(network)
    regex = '\\'
    regex += 'v'
    for row_num, octet in enumerate(group_octets(network)):
        # octet is a list of numbers in the octet in question
        print(f"row_num:{row_num}, octet:{octet}")
        if row_num == 3:
            regex += '(' + dd2Regex(build_dd(octet), anchor1='') + ')'
        else:
            regex += '(' + dd2Regex(build_dd(octet), anchor1='', anchor2='\.') + ')'
    return regex


if __name__ == "__main__":
    try:
        ipaddr = ip_network(sys.argv[-1])
    except ValueError as E:
        sys.exit(f"Error '{E}';  Check format of subnet - must be CIDR block: X.X.X.X/Y")
    else:
        regex = Network_Regex(sys.argv[-1])

