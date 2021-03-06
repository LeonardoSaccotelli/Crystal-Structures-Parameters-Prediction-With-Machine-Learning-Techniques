%NEURAL_NETWORK_FUNCTION Function to train a neural network regression model
% 	Input:
%  	1) training_dataset: 
%  	Table containing the same predictor and response columns as those 
%  	imported into the app.
%  
% 	2) target_feature_name: 
%  	String with the name of the target feature in the trainingData table.
%
%  	3) min_number_of_layer:
%  	Minimum number of layers in the neural network model
%
%  	4) max_number_of_layer:
%  	Maximum number of layers in the neural network model
%
%  	5) min_number_of_unit_for_layer:
%  	Minimum number of units (neuron) in each layer of the neural network
%
%  	6) max_number_of_unit_for_layer:
%  	Maximum number of units (neuron) in each layer of the neural network
%  
%  	7) max_objective_evaluations:
%  	Maximum number of objective functions to be evaluated in the
%  	optimization process
%  
%  	8) k-fold to use in cross-validation

%	Output:
%  	1) trained_model:
%  	Struct containing the trained regression model. The
%  	struct contains various fields with information about the trained
%  	model. 
%  	trainedModel.predictFcn: A function to make predictions on new data.
%
%  	2) validation_RMSE: 
%  	Double containing the RMSE which measure the performance of the trained
%  	model.
%       
%  	3) validation_predictions: 
%  	Vector with the predected values with respect the observed values in the
%  	training_dataset
%
%  	4) neural_network_settings_optimized:
%  	Struct with the optimized hyperparameters obtained by auto-tuning
%  	procedure
function [results] = ...
    neural_network_function(training_dataset, target_feature_name,...
    min_number_of_layer, max_number_of_layer, min_number_of_unit_for_layer,...
    max_number_of_unit_for_layer, max_objective_evaluations, k)
%% Extract predictors and response
input_table = training_dataset;

% Retrive all the features to be used in the training process
predictorNames = input_table.Properties.VariableNames;
predictorNames(:,(strncmp(predictorNames, target_feature_name,...
        strlength(target_feature_name)))) = [];
predictors = input_table(:, predictorNames);

% Retrive the target feature
response = input_table(:, target_feature_name);

%% Set parameters to be optimized during the auto-tuning procedure
params = hyperparameters("fitrnet",predictors,response);

% Set the min and max number of layers in the neural network.
% Min: 1, Max:5
params(1).Range = [min_number_of_layer max_number_of_layer];

% Set the number of units for each layer
% Default: 1 - 300
% Min: 1, Max: 400
for ii = 7:7+max_number_of_layer-1
    params(ii).Range = [min_number_of_unit_for_layer max_number_of_unit_for_layer];

    % If we set 5 as max number of layers, then we have to optimize also the
    % layer 4 and 5, and to do that, set to true the 'Optimize' param.
    params(ii).Optimize = true;
end

%% Train a regression model
rng("default");
neuralNetworkSettingsOptimized = fitrnet(...
    predictors, ...
    response, ...
    "OptimizeHyperparameters",params, ...
    "HyperparameterOptimizationOptions", ...
    struct(...
    "AcquisitionFunctionName","expected-improvement-plus", ...
    "MaxObjectiveEvaluations", max_objective_evaluations,"Repartition", true));

%% Create the result struct with predict function
predictorExtractionFcn = @(t) t(:, predictorNames);
neuralNetworkPredictFcn = @(x) predict(neuralNetworkSettingsOptimized, x);
trainedModel.predictFcn = @(x) neuralNetworkPredictFcn(predictorExtractionFcn(x));

%% Add additional fields to the result struct
trainedModel.RequiredVariables = input_table.Properties.VariableNames;
trainedModel.RegressionNeuralNetwork = neuralNetworkSettingsOptimized;
trainedModel.About = 'This struct is a neural network optimized trained model.';
trainedModel.HowToPredict = ...
    sprintf(['To make predictions on a new table, T, use: ' ...
    '\n  yfit = trained_model.predictFcn(T) \n' ...
    '\n \nThe table, T, must contain the variables returned by: ' ...
    '\n  trained_model.RequiredVariables \nVariable formats (e.g. matrix/vector, datatype)' ...
    ' must match the original training data. \nAdditional variables are ignored. ' ...
    '\n \nFor more information, ' ...
    'see <a href="matlab:helpview(fullfile(docroot, ''stats'', ''stats.map''), ' ...
    '''appregression_exportmodeltoworkspace'')">How to predict using an exported model</a>.']);

%% Perform cross-validation
partitioned_model = crossval(trainedModel.RegressionNeuralNetwork, 'KFold', k);
validationPredictions = kfoldPredict(partitioned_model);
%validationRMSE = sqrt(kfoldLoss(partitioned_model, 'LossFun', 'mse'));


validation_results = struct();
validation_results.validation_predictions = validationPredictions;

test_results = struct();

results = struct('model', trainedModel, 'validation_results',validation_results,...
    'test_results', test_results,'hyperparameters', neuralNetworkSettingsOptimized);

end