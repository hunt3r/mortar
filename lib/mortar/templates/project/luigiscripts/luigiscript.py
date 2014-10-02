import luigi
from luigi import configuration
from luigi.s3 import S3Target, S3PathTask

from mortar.luigi import mortartask

"""
  Luigi is a Python package that helps you build complex pipelines of batch jobs.
  The purpose of Luigi is to address all the plumbing typically associated with long-running 
  batch processes. In this example we will be running the ShutdownClusters task which is
  dependent on RunMyExamplePigScript task. This means the cluster will only shutdown after
  RunMyExamplePigScript (where the data transformation is actually happening) task is completed.

  This script is a 'fill in the blank' interaction. Feel free to alter it to run something
  you need.

  If you need some help, check out our amazing documentation:
  https://help.mortardata.com/technologies/luigi

"""


class RunMyExamplePigScript(mortartask.MortarProjectPigscriptTask):
  """
  This is a Luigi Task that extends MortarProjectPigscriptTask to run a Pig script on Mortar.
  """

  """
  Instantiating the parameter object.
  The output_path can be specified during runtime by adding the following to the run command:
  --output_path s3://my/output/path

  """
  output_path = luigi.Parameter() 

  def get_input_path(self):
    """
    Path to input data being analysed using the Pig script.
    You may choose not to pass this in through Luigi and just have this parameter in Pig.
    """
    return 's3://sample/input/path'

  def requires(self):
    """
    The requires method specifies a list of other Tasks that must be complete for this Task to run.
    In this case, we want to require that our input exists on S3 before we run the script. 
    S3PathTask validates that the specified file or directory exists on S3.
    """
    return [S3PathTask(get_input_path)]

  def project(self):
    """
    Name of Mortar Project to run.
    """
    return '<your-project>'
  
  def token_path(self):
    return self.output_path
  
  def parameters(self):
    """
    Parameters for this pig job.
    """
   return {'INPUT_PATH': get_input_path}
  
  def script(self):
    """
    Name of Pig script to run.
    """
    return 'pigScriptName'


class ShutdownClusters (mortartask.MortarClusterShutdownTask):
  """
  When the pipeline is completed, shut down all active clusters not currently running jobs.
  """
  output_path = luigi.Parameter() 

  def requires(self):
    """
    The ShutdownClusters task is dependent on RunMyExamplePigScript because a cluster should not 
    shut down until all the tasks are completed.
    This is a backwards way of saying 'shut down my cluster after running my task'.
    """
    return RunMyExamplePigScript (output_path = self.output_path)

  def output(self):
    """
    This output statement is needed because ShutdownClusters has no actual output. 
    We write a token with the class name to S3 to know that this task has completed 
    and it does not need to be run again.
    """
    return [S3Target('sample/s3/output/location')]

if __name__ == "__main__":
  """
  The final task in your pipeline, which will in turn pull in any dependencies need to be run
  should be called in the main method.
  In this case ShutdownClusters is being called.
  """
  luigi.run(main_task_cls= ShutdownClusters)