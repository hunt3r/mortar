import luigi
from luigi import configuration
from luigi.s3 import S3Target, S3PathTask

from mortar.luigi import mortartask

"""
  Luigi is a Python package that helps you build complex pipelines of batch
  jobs. The purpose of Luigi is to address all the plumbing typically
  associated with long-running batch processes. In this example we will be 
  running the ShutdownClusters task which is dependent on RunMyExamplePigScript
  task. This means the cluster will only shutdown after RunMyExamplePigScript
  (where the data transformation is actually happening) task is completed.

  This script is a 'fill in the blank' interaction. Feel free to alter it to
  run something you need.

  For full tutorials and in-depth Luigi documentation, visit:
  https://help.mortardata.com/technologies/luigi

  TO DO:
  Fill in input_path.


  To Run:
    mortar local:luigi luigiscripts/<%= project_name_alias %>_luigi.py
        -p output-base-path=s3://your/output_base_path
"""

MORTAR_PROJECT = <%= project_name_alias %>

# helper function
def create_full_path(base_path, sub_path):
    return '%s/%s' % (base_path, sub_path)

class RunMyExamplePigScript(mortartask.MortarProjectPigscriptTask):
  """
  This is a Luigi Task that extends MortarProjectPigscriptTask to run a Pig
  script on Mortar.
  """

  """
  The location in S3 where the output of the Mortar job will be written.
  """
  output_base_path = luigi.Parameter() 

  """
  Default cluster size to use for running Mortar jobs.  A cluster size of 0
  will run in Mortar's local mode.  This is a fast (and free!) way to run jobs
  on small data samples.  Cluster sizes >= 2 will run on a Hadoop cluster.
  """
  cluster_size = luigi.IntParmater(default=0)

  """
  Path to input data being analyzed using the Pig script.
  You may choose not to pass this in through Luigi and just have this parameter
  in Pig.
  """
  #TODO
  input_path = luigi.Parameter(default ='s3://your/input/path')


  def requires(self):
    """
    The requires method specifies a list of other Tasks that must be complete
    for this Task to run. In this case, we want to require that our input
    exists on S3 before we run the script. S3PathTask validates that the
    specified file or directory exists on S3.
    """
    return [S3PathTask(self.input_path()]

  def project(self):
    """
    Name of Mortar Project to run.
    """
    return MORTAR_PROJECT
  
  def token_path(self):
    """
    Luigi manages dependencies between tasks by checking for the existence of
    files.  When one task finishes it writes out a 'token' file that will
    trigger the next task in the dependency graph.  This is the base path for
    where those tokens will be written.
    """
    return self.output_base_path
  
  def parameters(self):
    """
    Parameters for this pig job.
    """
   return {'INPUT_PATH': self.input_path}
  
  def script(self):
    """
    Name of Pig script to run.
    """
    return <%= project_name_alias %>


class ShutdownClusters (mortartask.MortarClusterShutdownTask):
  """
  When the pipeline is completed, shut down all active clusters not currently
  running jobs.
  """
  output_base_path = luigi.Parameter() 

  def requires(self):
    """
    The ShutdownClusters task is dependent on RunMyExamplePigScript because a
    cluster should not shut down until all the tasks are completed. You can
    think of this as saying 'shut down my cluster after running my task'.
    """
    return RunMyExamplePigScript (output_base_path = self.output_base_path)

  def output(self):
    """
    This output statement is needed because ShutdownClusters has no actual
    output. We write a token with the class name to S3 to know that this task
    has completed and it does not need to be run again.
    """
    return [S3Target((create_full_path(self.output_base_path, 'ShutdownClusters'))]

if __name__ == "__main__":
  """
  The final task in your pipeline, which will in turn pull in any dependencies
  need to be run should be called in the main method.In this case 
  ShutdownClusters is being called.
  """
  luigi.run(main_task_cls= ShutdownClusters)