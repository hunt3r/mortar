from org.apache.pig.scripting import Pig
import os
import sys

if __name__ == "__main__":
    params       = Pig.getParameters()
    loader       = params["LOADER"]
    input_source = params["INPUT_SRC"]
    output_path  = params["OUTPUT_PATH"]
    infer_types  = params["INFER_TYPES"]

    if os.path.exists("../%s" % output_path):
        sys.stderr.write("ERROR: Output directory file: %s exists...Aborting!\n" % output_path)
    else:
        Pig.compileFromFile("../pigscripts/characterize.pig").bind({
            "LOADER"      : loader,
            "INPUT_SRC"   : input_source,
            "OUTPUT_PATH" : output_path,
            "INFER_TYPES" : infer_types
        }).runSingle()

        for root, _, files in os.walk("../%s" % output_path):
            for f in files:
                if f[0] != '.':
                    fullpath = os.path.join(root, f)
                    copypath = os.path.join(root, f + '.csv')
                    os.system ("cp %s %s" % (fullpath, copypath))
