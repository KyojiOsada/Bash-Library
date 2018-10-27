#!/bin/sh

# problem
# 1. can not handle multi generation hash array
# to jq or list
# 2. data type
# json


echo -ne "Content-type: text/html\n\n"

function parseWarpQuery()
{
	# Init
	local operators=('&' '\|' ';' ',' '==' '!=' '>=' '<=' '>>' '<<' '\?=' ':=' '%3E=' '%3C=' '%3E%3E' '%3C%3C' '=')
	local operator_class='&\|;,=!><\?:%'
	local conditions=('==' '!=' '>=' '<=' '>' '<' '?=' ':=' '=')
	local comparings=('==' '!=' '>=' '<=' '>' '<' '?=')
	local query_types=('ecl-string' 'ecl-data')
	local reverse_accepts=('application/json' 'application/json-sql')

	# Operators Regex Build
	local operator_regex=$(IFS="|"; echo "${operators[*]}")
	#echo $operator_regex

	#printenv
	# Query String Get
	local query_string="${QUERY_STRING};"

	local matches
	local operand
	local operator
	local post_match
	local query_type=''
	local query_elements
	while :; do
		## Operators Search
		matches=($(echo $query_string | sed -E "s/([a-z0-9_\-]*)(${operator_regex})(.*)/\1 \2 \3/i"))
		if [ -z ${matches} ]; then
			break
		fi

		## to Readable Variables
		operand=${matches[0]}
		operator=${matches[1]}
		post_match=${matches[2]}

		## Alias to Master Operator
		if [ $operator = '%3E=' ]; then
			operator='>='
		elif [ $operator = '%3C=' ]; then
			operator='<='
		elif [ $operator = '>>' ] && [ $operator = '%3E%3E' ]; then
			operator='>'
		elif [ $operator = '<<' ] && [ $operator = '%3C%3C' ]; then
			operator='<'
		elif [ $operator = '' ]; then
			operator='<='
		fi

		## Query Type Get Header Extract
		if [ $operator = ':=' ] && [ $operand = 'query_type' ]; then
			query_type=($(echo $post_match | sed -E "s/([^${operator_class}]*)(${operator_regex})/\1 \2/g"))
		fi

		## Query Elements Mapping
		query_elements+=($operand)
		query_elements+=($operator)

		## Post Matcher to Query String
		query_string=$post_match
	done
	#echo ${query_elements[*]}

	# Query-Type Header Check
	if [ -z "$query_type" ] && [ -n "$QUERY_TYPE" ]; then
		query_type=$QUERY_TYPE
	elif [ -z "$query_type" ]; then
		query_type=null
	fi
	#echo $query_type

	# Query-Type Header Validation
	if ! $(echo ${query_types[@]} | grep -q "$query_type"); then
		query_type=${query_types[0]}
	fi
	#echo $query_type

	# List to Hash Query Elements by Condition Operators
	local query_element
	local i=-1
	local h
	local j
	local k
	local casted_data
	local d
	local option=''
	local write=''
	local comp=''
	for query_element in ${query_elements[@]}; do
		## Current Key Increment
		i=$((i + 1))

		## Not Condition Operators
		if ! $(echo ${conditions[@]} | grep -q "$query_element"); then
			continue
			fi

		## Key Number
		h=$(($i - 1))
		j=$(($i + 1))
		k=$(($i + 2))

		## Data Type Cast
		### Non-Quoted Data to Quoted Data Cast for Default
		if [ '_true_' != $(echo ${query_elements[$j]} | sed -E "s/^('.*'|\".*\")$/_true_/") ]; then
			cast_data="\"${query_elements[$j]}\""
		fi

		### Strict Data type
		if [ $query_type = 'ecl-data' ]; then
			### Boolean
			if [ ${query_elements[$j]} = 'true' ] ||
			[ ${query_elements[$j]} = 'false' ] ||
			### Null
			[ ${query_elements[$j]} = 'null' ] ||
			#### Integer
			[ true = $(echo ${query_elements[$j]} | sed -E "s/^([0-9]|[1-9][0-9]+)$/true/") ] ||
			### Float
			[ true = $(echo ${query_elements[$j]} | sed -E "s/^([0-9]\.[0-9]+|[1-9][0-9]\.[0-9]+)$/true/") ]; then
				cast_data="${query_elements[$j]}"
			fi
		fi

		## Query Parameters Mapping
		### Option Parameters
		d=''
		if [ $query_element = ':=' ]; then
			if [ "$option" != '' ]; then
				d=','
			fi
			option+="${d}\"${query_elements[$h]}\":${cast_data}"
			continue
		### Write Parameters
		elif [ $query_element = '=' ]; then
			if [ "$write" != '' ]; then
				d=','
			fi
			write+="${d}\"${query_elements[$h]}\":${cast_data}"
			continue
		### Conditional Parameters
		elif $(echo ${comparings[@]} | grep -q "$query_element"); then
			if [ "$comp" != '' ]; then
				d=','
			fi
			comp+="${d}{\"role\":\"name\", \"data\":\"${query_elements[$h]}\"}"
			d=','
			comp+="${d}{\"role\":\"operator\", \"data\":\"${query_element[$i]}\"}"
			comp+="${d}{\"role\":\"value\", \"data\":${cast_data}}"
			comp+="${d}{\"role\":\"logical\", \"data\":\"${query_elements[$k]}\"}"
		fi
	done

	local json="{\"options\":{${option}}},{\"writes\":{${write}}},{\"comps\":[${comp}]}"


	echo $json
	exit

}

parseWarpQuery
