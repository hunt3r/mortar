@outputSchema("five:tuple(vals:tuple(v1:double, v2:double, v3:double, v4:double, v5:double), type:chararray, orig:tuple(v1:chararray, v2:chararray, v3:chararray, v4:chararray, v5:chararray), val_counts:tuple(v1:long, v2:long, v3:long, v4:long, v5:long))")
def key_bag_to_tuple(input_bag):
    output = []
    #sort by val_count
    input_bag = sorted(input_bag, key=lambda tup: tup[4], reverse=True)
    vals = [None, None, None, None, None]
    val_counts = [None, None, None, None, None]
    orig_vals = [None, None, None, None, None]
    for idx, t in enumerate(input_bag):
        vals[idx] = t[2]
        orig_vals[idx] = t[3]
        val_counts[idx] = t[4]
    val_tup = tuple(vals)
    val_count_tup = tuple(val_counts)
    orig_val_tup = tuple(orig_vals)
    output.append(val_tup)
    if all(i[1] == "NULL" for i in input_bag):
        output.append("NULL")
    else:
        for t in input_bag:
            if t[1] != "NULL":
                output.append(t[1])
                break
    output.append(orig_val_tup)
    output.append(val_count_tup)
    return tuple(output)
    
