classdef (Abstract, CaseInsensitiveProperties = true) statsPlot < matlab.mixin.SetGet
%STATSPLOT An abstract superclass for classes that plot statistics
% 
%   As an abstract class, this class cannot be instantiated. It provides no
%   public methods. The class is a super class for:
%       - iosr.statistics.boxPlot
%       - iosr.statistics.functionalSpreadPlot

    properties (AbortSet)
        handles = struct             % Structure containing handles to plot objects.
    end
    
    properties (AbortSet, Abstract)
        limit                       % Mode indicating the limits that define outliers.
        method                      % The method used to calculate the quantiles.
    end
    
    properties (SetAccess = protected)
        x                           % The x data.
        y                           % The y data.
        weights = [];               % The weights for y.
        statistics = struct         % Structure containing the statistics used for the plot.
    end
    
    properties (Access = protected)
        outDims                     % dimensions of output
        ydims                       % dimensions of y
    end
    
    properties (SetAccess = protected, Dependent, Hidden)
        axes = []                   % The parent axes of the plot.
        fig = []                    % The parent figure of the plot.
    end
    
    methods
        
        % constructor
        function obj = statsPlot()
            
        end
        
        %% dependent handle getters
        
        % these are all deprecated and the handles moved to the obj.handles struct
    
        function val = get.axes(obj)
            warning('''obj.axes'' is deprecated. Use ''obj.handles.axes'' instead.');
            val = obj.handles.axes;
        end
        
        function val = get.fig(obj)
            warning('''obj.fig'' is deprecated. Use ''obj.handles.fig'' instead.');
            val = obj.handles.fig;
        end
        
    end
    
    methods (Access = protected)
        
        % Get X and Y data from input
        function start = getXY(obj,varargin)
            
            if nargin > 1
                if isnumeric(varargin{2})
                    obj.x = varargin{1};
                    obj.y = varargin{2};
                    if isvector(obj.y) % ensure y is column vector
                        obj.y = obj.y(:);
                    end
                    start = 3;
                else
                    obj.y = varargin{1};
                    if isvector(obj.y) % ensure y is column vector
                        obj.y = obj.y(:);
                    end
                    obj.x = 1:size(obj.y,2);
                    start = 2;
                end
            else
                obj.y = varargin{1};
                if isvector(obj.y) % ensure y is column vector
                    obj.y = obj.y(:);
                end
                obj.x = 1:size(obj.y,2);
                start = 1;
            end
            
            if size(obj.y,1)==1
                error('Data are plotted for each column. Each column in the input has only one data point.')
            end
            
            % check x/y data
            assert(isvector(obj.x),'x must be a vector');
            assert(isnumeric(obj.y),'y must be a numeric column vector or matrix');
            assert(numel(obj.x)==size(obj.y,2),'x must have the same number of elements as y has columns')
            
            % size of input
            obj.ydims = size(obj.y);
            obj.outDims = obj.ydims; obj.outDims(1) = 1;
            
            if length(obj.outDims) < 3
                obj.outDims = [obj.outDims 1];
            end
            
        end
        
        % Check the weights are the correct size, or set the weights to 1
        % if no weights are provided
        function checkWeights(obj)
            
            if isempty(obj.weights)
                obj.weights = ones(size(obj.y));
            else
                assert(isequal(size(obj.y),size(obj.weights)),'weights must be the same size as y')
            end
            
        end
        
        % Remove NaNs
        function removeNaN(obj)
            
            % remove NaN columns
            if isnumeric(obj.x)
                obj.x = obj.x(~isnan(obj.x));
                obj.y = obj.y(:,~isnan(obj.x),:);
                obj.y = reshape(obj.y,obj.ydims);
                obj.weights = obj.weights(:,~isnan(obj.x),:);
                obj.weights = reshape(obj.weights,obj.ydims);
            end
            
        end
        
        % set plot properties
        function setProperties(obj,start,ngin,vgin)
            
            % read parameter/value inputs
            if start < ngin % if parameters are specified
                nArgs = length(vgin)-start+1;
                if round(nArgs/2)~=nArgs/2
                   error('Properties must be propertyName/propertyValue pairs')
                end
                % overwrite defults
                for pair = reshape(vgin(start:end),2,[]) % pair is {propName;propValue}
                    obj.(pair{1}) = pair{2};
                end
            end
            
        end
        
        % calculate the statistics for the plot
        function calculateStats(obj)
            
            % calculate stats
            obj.statistics.median = iosr.statistics.quantile(obj.y,.5,[],obj.method,obj.weights); % median
            outsize = size(obj.statistics.median);
            obj.statistics.mean = zeros(outsize); % sample mean
            obj.statistics.std = zeros(outsize); % sample standard deviation
            obj.statistics.N = zeros(outsize); % sample size
            obj.statistics.Q1 = zeros(outsize); % lower quartile
            obj.statistics.Q3 = zeros(outsize); % upper quartile
            obj.statistics.IQR = zeros(outsize); % inter-quartile range
            obj.statistics.notch_u = zeros(outsize); % high notch value
            obj.statistics.notch_l = zeros(outsize); % low notch value
            obj.statistics.min = zeros(outsize); % minimum (excluding outliers)
            obj.statistics.max = zeros(outsize); % maximum (excluding outliers)
            subidx = cell(1,length(obj.outDims));
            for n = 1:prod(obj.outDims)
                [subidx{:}] = ind2sub(obj.outDims, n);
                subidxAll = subidx;
                subidxLogical = subidx;
                subidxAll{1} = ':';
                [~,obj.statistics.N(subidx{:})] = iosr.statistics.quantile(obj.y(subidxAll{:}),0.25,[],obj.method,obj.weights(subidxAll{:}));
                temp = obj.y(subidxAll{:});
                obj.statistics.mean(subidx{:}) = mean(temp(~isnan(temp)));
                obj.statistics.std(subidx{:}) = std(temp(~isnan(temp)));
                obj.statistics.Q1(subidx{:}) = iosr.statistics.quantile(obj.y(subidxAll{:}),0.25,[],obj.method,obj.weights(subidxAll{:}));
                obj.statistics.Q3(subidx{:}) = iosr.statistics.quantile(obj.y(subidxAll{:}),0.75,[],obj.method,obj.weights(subidxAll{:}));
                obj.statistics.IQR(subidx{:}) = obj.statistics.Q3(subidx{:})-obj.statistics.Q1(subidx{:});
                obj.statistics.notch_u(subidx{:}) = obj.statistics.median(subidx{:})+(1.58*obj.statistics.IQR(subidx{:})/sqrt(obj.statistics.N(subidx{:})));
                obj.statistics.notch_l(subidx{:}) = obj.statistics.median(subidx{:})-(1.58*obj.statistics.IQR(subidx{:})/sqrt(obj.statistics.N(subidx{:})));
                if isnumeric(obj.limit)
                    upper_limit = iosr.statistics.quantile(obj.y(subidxAll{:}),max(obj.limit)/100,[],obj.method,obj.weights(subidxAll{:}));
                    lower_limit = iosr.statistics.quantile(obj.y(subidxAll{:}),min(obj.limit)/100,[],obj.method,obj.weights(subidxAll{:}));
                else
                    switch lower(obj.limit)
                        case '1.5iqr'
                            upper_limit = obj.statistics.Q3(subidx{:})+1.5*obj.statistics.IQR(subidx{:});
                            lower_limit = obj.statistics.Q1(subidx{:})-1.5*obj.statistics.IQR(subidx{:});
                        case '3iqr'
                            upper_limit = obj.statistics.Q3(subidx{:})+3*obj.statistics.IQR(subidx{:});
                            lower_limit = obj.statistics.Q1(subidx{:})-3*obj.statistics.IQR(subidx{:});
                        case 'none'
                            upper_limit = Inf;
                            lower_limit = -Inf;
                        otherwise
                            error('Unknown ''limit'': ''%s''',obj.limit)
                    end
                end
                obj.statistics.outliers_IX(subidxAll{:}) = obj.y(subidxAll{:})>upper_limit | obj.y(subidxAll{:})<lower_limit;
                subidxLogical{1} = ~obj.statistics.outliers_IX(subidxAll{:});
                obj.statistics.min(subidx{:}) = min(min(obj.y(subidxLogical{:})),obj.statistics.Q1(subidx{:})); % min excl. outliers but not greater than lower quartile
                obj.statistics.max(subidx{:}) = max(max(obj.y(subidxLogical{:})),obj.statistics.Q3(subidx{:})); % max excl. outliers but not less than upper quartile
                subidxLogical{1} = obj.statistics.outliers_IX(subidxAll{:});
                obj.statistics.outliers{subidx{:}} = obj.y(subidxLogical{:});
            end
            
        end
        
    end
    
end