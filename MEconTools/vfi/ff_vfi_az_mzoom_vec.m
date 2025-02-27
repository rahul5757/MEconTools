%% FF_VFI_AZ_MZOOM_VEC (vectorized zoom-in exact choice) Dynamic Savings Problem
%    Fast vectorized solution for solving the dynamic programming problem
%    with fixed asset state space, but continuous asset choices. Solution
%    obtained via bi(multi)-section. Solves for the fraction of resources
%    to save, this is then translated to asset choice level
%
%    Uses first order conditions. The first order condition has two
%    components: let u(c(ap,a,z)) be current utility, let beta*EV(ap|z) be
%    the expected value from making choice ap given current shock z.
%    d(u)/d(ap) is analytical; the EV(ap|z) are a set of linear splines
%    each spline for each shock point z, dEV/d(ap) are just the slopes for
%    each spline segment. With both partials, we can easily use mzoomtion
%    to solve for optimal exact choices.
%
%    Obtains policy and value functions. Shock is AR(1). This function is
%    looped, and extremely slow when state-space increases in size. This
%    function is useful as a working template for developing models that
%    rely on asset and shocks.
%
%    * MP_PARAMS controls model preference, prices, shock and asset grid
%    parameters.
%    * MP_SUPPORT controls convergence criterion, printing and summary
%    controls
%
%    mp_params = containers.Map('KeyType','char', 'ValueType','any');
%    mp_params('fl_crra') = 1.5;
%    mp_params('fl_beta') = 0.95;
%    mp_params('fl_w') = 1.05;
%    mp_params('fl_r') = 0.03;
%    mp_params('fl_a_min') = 0;
%    mp_params('fl_a_max') = 50;
%    mp_params('it_a_n') = 25;
%    mp_params('st_grid_type') = 'grid_powerspace';
%    mp_params('fl_z_persist') = 0.60;
%    mp_params('fl_shk_std') = 0.10;
%    mp_params('it_z_n') = 5;
%    mp_params('st_grid_type') = 'grid_powerspace';
%
%    mp_support = containers.Map('KeyType','char', 'ValueType','any');
%    mp_support('fl_lowestc') = -10e10;
%    mp_support('it_maxiter_val') = 500;
%    mp_support('fl_tol_val') = 10e-5;
%    % printer various information
%    mp_support('bl_timer') = true;
%    mp_support('bl_print_params') = false;
%    mp_support('bl_print_iterinfo') = false;
%    % These names must match keys of mp_solu: v=value, ap=savings choice,
%    c=consumption, y=income, coh=cash-on-hand (income + savings),
%    savefraccoh = ap/coh.
%    % what outcomes to store in the mp_solu for export
%    mp_support('ls_slout') = {'v', 'ap', 'c', 'y', 'coh', 'savefraccoh'};
%    % outcome for ff_container_map_display
%    mp_support('ls_ffcmd') = {'v', 'ap', 'c', 'y', 'coh', 'savefraccoh'};
%    % outcome for ff_summ_nd_array
%    mp_support('ls_ffsna') = {'v', 'ap', 'c', 'y', 'coh', 'savefraccoh'};
%    % outcome for ff_graph_grid
%    mp_support('ls_ffgrh') = {'v', 'ap', 'c', 'y', 'coh', 'savefraccoh'};
%    % outcome for ff_summ_nd_array
%    mp_support('ffsna_opt_it_row_n_keep') = 10;
%    % outcome for ff_summ_nd_array
%    mp_support('ffsna_opt_it_col_n_keep') = 9;
%
%    [MP_VALPOL_OUT, FLAG] = FF_VFI_AZ_MZOOM_VEC() default savings and
%    shock model simulation
%
%    [MP_VALPOL_OUT, FLAG] = FF_VFI_AZ_MZOOM_VEC(MP_PARAMS) change model
%    parameters through MP_PARAMS
%
%    [MP_VALPOL_OUT, FLAG] = FF_VFI_AZ_MZOOM_VEC(MP_PARAMS, MP_SUPPORT)
%    change various printing, storaging, graphing, convergence etc controls
%    through MP_SUPPORT
%
%    [MP_VALPOL_OUT, FLAG] = FF_VFI_AZ_MZOOM_VEC(MP_PARAMS, MP_SUPPORT,
%    MP_SUPPORT_GRAPH) also changing graphing options, see the
%    FF_GRAPH_GRID function for what key value paris can be specified.
%
%    see also FX_VFI_AZ_MZOOM_VEC, FF_VFI_AZ_MZOOM_LOOP, FF_VFI_AZ_LOOP,
%    FF_VFI_AZ_VEC, FF_VFI_AZ_MZOOM_LOOP, FF_VFI_AZ_MZOOM_VEC,
%    FF_GRAPH_GRID
%

%%
function [mp_valpol_out, flag] = ff_vfi_az_mzoom_vec(varargin)

%% Set Default and Parse Inputs
if (~isempty(varargin))

    if (length(varargin) == 1)
        [mp_params_ext] = varargin{:};
    elseif (length(varargin) == 2)
        [mp_params_ext, mp_support_ext] = varargin{:};
    elseif (length(varargin) == 3)
        [mp_params_ext, mp_support_ext, mp_support_graph_ext] = varargin{:};
    end

else
    close all;
    mp_support_ext = containers.Map('KeyType','char', 'ValueType','any');
    mp_support_ext('bl_timer') = true;
    mp_support_ext('bl_print_params') = true;
    mp_support_ext('bl_print_iterinfo') = true;
    mp_support_ext('ls_ffcmd') = {'v', 'ap', 'c', 'y', 'coh', 'savefraccoh'};
    mp_support_ext('ls_ffsna') = {'ap'};
    mp_support_ext('ls_ffgrh') = {'v', 'ap', 'c', 'y', 'savefraccoh'};
    mp_support_ext('ls_store') = {'v', 'ap', 'c', 'y', 'coh'};
    mp_support_ext('ffsna_opt_it_row_n_keep') = 10;
    mp_support_ext('ffsna_opt_it_col_n_keep') = 9;

end

%% Default Model Parameters
% support_map
mp_params = containers.Map('KeyType','char', 'ValueType','any');
mp_params('fl_crra') = 1.5;
mp_params('fl_beta') = 0.95;

mp_params('fl_w') = 1.40;
mp_params('fl_r') = 0.04;

mp_params('fl_a_min') = 0;
mp_params('fl_a_max') = 50;
mp_params('it_a_n') = 100;
mp_params('st_grid_type') = 'grid_powerspace';

mp_params('fl_z_persist') = 0.80;
mp_params('fl_shk_std') = 0.20;
mp_params('it_z_n') = 7;

% override default support_map values
if (length(varargin)>=1)
    mp_params = [mp_params; mp_params_ext];
end

%% Parse mp_params
params_group = values(mp_params, {'fl_crra', 'fl_beta'});
[fl_crra, fl_beta] = params_group{:};
params_group = values(mp_params, {'fl_w', 'fl_r'});
[fl_w, fl_r] = params_group{:};
params_group = values(mp_params, {'fl_a_min', 'fl_a_max', 'it_a_n', 'st_grid_type'});
[fl_a_min, fl_a_max, it_a_n, st_grid_type] = params_group{:};
params_group = values(mp_params, {'fl_z_persist', 'fl_shk_std', 'it_z_n'});
[fl_z_persist, fl_shk_std, it_z_n] = params_group{:};

%% Generate A and Z Grids
% Same min and max and grid points
[ar_a] = ff_saveborr_grid(fl_a_min, fl_a_max, it_a_n, st_grid_type);
ar_a = ar_a';

% shock vector and transition, normalize mean exp(shk) to 1
[ar_z, mt_z_trans] = ffy_rouwenhorst(fl_z_persist, fl_shk_std, it_z_n);
% normalize mean of exp to 1, fl_shk_std does not shift mean.
ar_z_stationary = mt_z_trans^1000;
ar_z_stationary = ar_z_stationary(1,:);
fl_labor_agg = ar_z_stationary*exp(ar_z);
ar_z = exp(ar_z')/fl_labor_agg;

%% mp_mzoom_ctrlinfo Parameters
% support_map
mp_mzoom_ctrlinfo = containers.Map('KeyType','char', 'ValueType','any');

% number of a*z points to concurrently evaluate 
mp_mzoom_ctrlinfo('it_states_n') = it_z_n*it_a_n;
% within each multisection iteration, points to solve at
mp_mzoom_ctrlinfo('it_mzoom_jnt_pnts') = 50;
% number of iterations
mp_mzoom_ctrlinfo('it_mzoom_max_iter') = 3;
% zoom ratio 
mp_mzoom_ctrlinfo('it_mzoom_zm_ratio') = 0;
% starting savings share, common for all
mp_mzoom_ctrlinfo('fl_x_left_start') = 0;
% max savings share, common for all
mp_mzoom_ctrlinfo('fl_x_right_start') = 1-10e-6;

%% Default Support Parameters
% support_map
mp_support = containers.Map('KeyType','char', 'ValueType','any');

% Model Control
mp_support('fl_lowestc') = -1e10;

% Iteration Control
mp_support('it_maxiter_val') = 500;
mp_support('fl_tol_val') = 1e-5;

% printer various information
mp_support('bl_timer') = true;
mp_support('bl_print_params') = false;
mp_support('bl_print_iterinfo') = false;

% These names must match keys of mp_solu:
% what outcomes to store in the mp_solu for export
mp_support('ls_slout') = {'v', 'ap', 'c', 'y', 'coh', 'savefraccoh'};
% outcome for ff_container_map_display
mp_support('ls_ffcmd') = {'ap'};
% outcome for ff_summ_nd_array
mp_support('ls_ffsna') = {};
% outcome for ff_graph_grid
mp_support('ls_ffgrh') = {};
% outcome for ff_summ_nd_array
mp_support('ffsna_opt_it_row_n_keep') = 10;
% outcome for ff_summ_nd_array
mp_support('ffsna_opt_it_col_n_keep') = 9;

% add zoom controls to mp_support
mp_support = [mp_support; mp_mzoom_ctrlinfo];

% override default support_map values
if (length(varargin)>=2 || isempty(varargin))
    mp_support = [mp_support; mp_support_ext];
end

% Parse mp_support
params_group = values(mp_support, {'it_mzoom_jnt_pnts'});
[it_mzoom_jnt_pnts] = params_group{:};
params_group = values(mp_support, {'fl_lowestc'});
[fl_lowestc] = params_group{:};
params_group = values(mp_support, {'it_maxiter_val', 'fl_tol_val'});
[it_maxiter_val, fl_tol_val] = params_group{:};
params_group = values(mp_support, {'bl_timer', 'bl_print_params', 'bl_print_iterinfo'});
[bl_timer, bl_print_params, bl_print_iterinfo] = params_group{:};
params_group = values(mp_support, ...
    {'ls_slout', 'ls_ffcmd', 'ls_ffsna', 'ls_ffgrh',...
    'ffsna_opt_it_row_n_keep', 'ffsna_opt_it_col_n_keep'});
[ls_slout, ls_ffcmd, ls_ffsna, ls_ffgrh,...
    ffsna_opt_it_row_n_keep, ffsna_opt_it_col_n_keep] = params_group{:};

%% Whether Additional Outcomes Should be Stored
% when state space are large, might not be a good idea to store all
% possible model output matrixes, but could be controlled with these if
% things should be outputed. If bl_store_more = true, will output store all
% additional possible outcomes if bl_vfi_store_all = true. Internally,
% which output becomes tabular or graphical controled by ls_ffcmd,
% ls_ffsna, and ls_ffgrh.

% If to store additional outcomes
cl_more = {'c', 'y', 'coh', 'savefraccoh'};
ar_find_slout = cell2mat(cellfun(@(m) find(strcmp(ls_slout, m)), cl_more, 'UniformOutput', false));
ar_find_ffcmd = cell2mat(cellfun(@(m) find(strcmp(ls_ffcmd, m)), cl_more, 'UniformOutput', false));
ar_find_ffsna = cell2mat(cellfun(@(m) find(strcmp(ls_ffsna, m)), cl_more, 'UniformOutput', false));
ar_find_ffgrh = cell2mat(cellfun(@(m) find(strcmp(ls_ffgrh, m)), cl_more, 'UniformOutput', false));
if (length(ar_find_slout) + length(ar_find_ffcmd) + length(ar_find_ffsna) + length(ar_find_ffgrh) >1)
    bl_store_more = true;
end

%% Initialize Matrix
mt_val_lst = zeros(length(ar_a),length(ar_z));
mt_val_cur = mt_val_lst;
mt_aprime_lst = zeros(length(ar_a),length(ar_z));
mt_aprime_cur = mt_aprime_lst;
mt_aprime_idx = zeros(length(ar_a),length(ar_z));
ar_val_diff_norm = zeros([it_maxiter_val, 1]);
ar_pol_diff_norm = zeros([it_maxiter_val, 1]);
mt_pol_perc_change = zeros([it_maxiter_val, length(ar_z)]);

if (bl_store_more)
    mt_c = zeros(length(ar_a),length(ar_z));
    mt_y = zeros(length(ar_a),length(ar_z));
    mt_coh = zeros(length(ar_a),length(ar_z));
end

%% Define Functions

% Current Function and their Derivatives
if(fl_crra == 1)
    f_util = @(c) log(c);
    f_du_da = @(c) -1./(c);
else
    f_util = @(c) (((c).^(1-fl_crra)-1)./(1-fl_crra));
    f_du_da = @(c) -1./(c.^fl_crra);
end

% Utility
f_U = @(u, Ev) (u + fl_beta.*Ev);
f_FOC = @(duda, devda) (duda + fl_beta.*devda);

% resources
f_y = @(z, b) (z*fl_w + b.*(fl_r));
f_coh = @(z, b) (z*fl_w + b.*(1+fl_r));
f_cons = @(z, b, bprime) (f_coh(z, b) - bprime);

%% Compute Fixed Resource Matrix by States

% C1. Resource Matrix Broadcast: length(ar_a) by length(ar_z) matrix
mt_resources = f_coh(ar_z, ar_a');
mt_z_ctr = repmat(1:length(ar_z), [length(ar_a), 1]);

% C2. Flatten the resource matrix, amz = a mesh z:
ar_resources_amz = mt_resources(:);
ar_z_ctr_amz = mt_z_ctr(:);
% z needs to be meshed with percentage choices, smz=states mesh z
mt_z_ctr_amz_smz = repmat(ar_z_ctr_amz, [1, it_mzoom_jnt_pnts]);
ar_z_ctr_amz_smz = mt_z_ctr_amz_smz(:);

%% Dynamically Solve
if (bl_timer)
    tic
end

% initialize
fl_diff = 1;
it_iter = 0;

% After converge, one more iteration to store results
bl_continue = true;
bl_converged = false;

% Loop 0, continuous VFI iteration until convergence
while bl_continue

    % A. Solve For EV(ap,z) = EV(ap,zp|z)f(zp|z) for all possible ap points
    % Note that EV(ap,z) is unrelated to current asset state a
    mt_ev_ap_z = zeros(length(ar_a), length(ar_z));
    for it_z_ctr = 1:length(ar_z)
        for it_ap_ctr = 1:length(ar_a)
            % Add to each cell of mt_ev_ap_z, integrating over f(zp|z)
            for it_zprime_ctr = 1:length(ar_z)
                mt_ev_ap_z(it_ap_ctr, it_z_ctr) = mt_ev_ap_z(it_ap_ctr, it_z_ctr) ...
                    + mt_z_trans(it_z_ctr,it_zprime_ctr)*mt_val_lst(it_ap_ctr,it_zprime_ctr);
            end
        end
    end

    % B. z specific EV Slope: EV(ap,z)/d(ap)
    % Given the discretized EV matrix structure, we have a matrix of
    % splines, get the slopes of the spline segments. These are the
    % derivatives of the marginal effects of additional savings for each
    % splinde segment conditional on shock.
    mt_deri_dev_dap = diff(mt_ev_ap_z)./diff(ar_a');

    % C. Generate Vectorized Utility Evaluator
    % x = fl_aprime_frac
    fc_ffi_vec_u_v_ap = @(x) ffi_vec_u_v_ap(...
        x, ar_a, ...
        ar_resources_amz, ar_z_ctr_amz_smz, mt_ev_ap_z, mt_deri_dev_dap, ...
        f_util, f_U);

    % D. Solve via Bisection
    [ar_opti_saveborr_frac_amz] = ...
        ff_optim_mzoom_savezrone(fc_ffi_vec_u_v_ap, ...
        false, false, mp_support);

    % F. Evaluate
    [ar_val_opti_amz, ar_aprime_amz, ar_c_opti_amz] = ffi_vec_u_v_ap(...
        ar_opti_saveborr_frac_amz, ar_a, ...
        ar_resources_amz, ar_z_ctr_amz, ...
        mt_ev_ap_z, mt_deri_dev_dap, ...
        f_util, f_U);

    % G. Record Results
    mt_val_cur = reshape(ar_val_opti_amz, [length(ar_a),length(ar_z)]);
    mt_aprime_cur = reshape(ar_aprime_amz, [length(ar_a),length(ar_z)]);

    % H. Save Additional Results
    if bl_converged
        [~, ar_opti_a_idx_amz] = min(abs(ar_a-ar_aprime_amz),[],2);
        mt_aprime_idx = reshape(ar_opti_a_idx_amz, [length(ar_a),length(ar_z)]);
        if (bl_store_more)
            mt_c = reshape(ar_c_opti_amz, [length(ar_a),length(ar_z)]);
            mt_y = mt_resources - ar_a';
            mt_coh = mt_resources;
        end
    end

    % I. Iteration Convergence Checking
    % Continuation Conditions:
    it_iter = it_iter + 1;
    fl_diff = norm(mt_val_cur-mt_val_lst);
    diff_pol = norm(mt_aprime_cur-mt_aprime_lst);

    % Difference across iterations
    if (bl_print_iterinfo)
        ar_val_diff_norm(it_iter) = fl_diff;
        ar_pol_diff_norm(it_iter) = diff_pol;
        mt_pol_perc_change(it_iter, :) = sum((mt_aprime_cur ~= mt_aprime_lst))/(length(ar_a));
    end

    % Update
    mt_val_lst = mt_val_cur;
    mt_aprime_lst = mt_aprime_cur;

    % Update Continue Criterion
    if bl_converged
        bl_continue = false;
    elseif(fl_diff <= fl_tol_val || it_iter >= it_maxiter_val)
        bl_converged = true;
    end

    % J. Print Iteration Record
    if(bl_print_iterinfo)
        disp(['ff_vfi_az_mzoom_loop, it_iter:' num2str(it_iter) ...
            ', fl_diff:' num2str(fl_diff)]);
    end

end

%% Convergence Results
it_iter_last = it_iter;
if fl_diff <= fl_tol_val || it_iter>=it_maxiter_val
    if (it_iter>=it_maxiter_val)
        flag = 2;
    else
        flag = 1;
    end
else
    flag = 0;
end

if (bl_timer)
    toc
end

%% Results for Printing, and Graphing
mp_print_graph = containers.Map('KeyType','char', 'ValueType','any');
mp_print_graph('v') = mt_val_cur;
mp_print_graph('ap') = mt_aprime_cur;
if (bl_store_more)
    mp_print_graph('c') = mt_c;
    mp_print_graph('y') = mt_y;
    mp_print_graph('coh') = mt_coh;
    mp_print_graph('savefraccoh') = mt_aprime_cur./mt_coh;
end

%% Print Parameter Information
if (bl_print_params)
    ff_container_map_display(mp_params);
    ff_container_map_display(mp_support);
end

%% Show Value Function Convergence Information
if (bl_print_iterinfo)

    it_z_select = unique(round(linspace(1,length(ar_z), 7)));
    ar_z_select = ar_z(it_z_select);
    tb_valpol_alliter = array2table([ar_val_diff_norm(1:it_iter_last)';...
        ar_pol_diff_norm(1:it_iter_last)';...
        mt_pol_perc_change(1:it_iter_last,it_z_select)']');
    ar_st_col_zs = matlab.lang.makeValidName(strcat('z=', string(ar_z_select)));
    cl_col_names = ['valgap', 'polgap', ar_st_col_zs];
    cl_row_names = strcat('iter=', string(1:it_iter_last));
    tb_valpol_alliter.Properties.VariableNames = cl_col_names;
    tb_valpol_alliter.Properties.RowNames = cl_row_names;
    disp('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx');
    disp('Value Function Iteration Per Iteration Changes');
    disp('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx');
    disp('valgap = norm(mt_val - mt_val_cur): value function difference across iterations');
    disp('polgap = norm(mt_pol_a - mt_pol_a_cur): policy function difference across iterations');
    disp(['z1 = z1 perc change: sum((mt_pol_a ~= mt_pol_a_cur))/(it_a_n): percentage of state space'...
        ' points conditional on shock where the policy function is changing across iterations']);
    disp(tb_valpol_alliter);

end

%% ls_ffcmd summary
if (~isempty(ls_ffcmd))
    mp_ffcmd = containers.Map(ls_ffcmd, values(mp_print_graph, ls_ffcmd));
    ff_container_map_display(mp_ffcmd, ffsna_opt_it_row_n_keep, ffsna_opt_it_col_n_keep);
end

%% ls_ffsna summarize full
if (~isempty(ls_ffsna))

    % container map subseting
    mp_ffsna = containers.Map(ls_ffsna, values(mp_print_graph, ls_ffsna));

    % ff_summ_nd_array parameters
    it_aggd = 0;
    bl_row = 1;
    ar_permute = [2,1];
    ar_st_stats = ["mean"];
    bl_print_table = true;
    cl_mp_datasetdesc = {};
    cl_mp_datasetdesc{1} = containers.Map({'name', 'labval'}, {'a', ar_a});
    cl_mp_datasetdesc{2} = containers.Map({'name', 'labval'}, {'z', ar_z});

    % summarize
    param_map_keys = keys(mp_ffsna);
    param_map_vals = values(mp_ffsna);
    for i = 1:length(mp_ffsna)
        st_mt_name = param_map_keys{i};
        mt_cur = param_map_vals{i};
        st_title = ['ff_vfi_az_vec, outcome=' st_mt_name];
        ff_summ_nd_array(st_title, mt_cur, ...
            bl_print_table, ar_st_stats, it_aggd, bl_row, ...
            cl_mp_datasetdesc, ar_permute);
    end

end

%% ls_ffgrh graph
if (~isempty(ls_ffgrh))

    % container map subseting
    mp_ffgrh = containers.Map(ls_ffgrh, values(mp_print_graph, ls_ffgrh));

    % container map settings
    mp_support_graph = containers.Map('KeyType', 'char', 'ValueType', 'any');
    mp_support_graph('cl_st_xtitle') = {'savings states, a'};
    mp_support_graph('st_legend_loc') = 'best';
    mp_support_graph('bl_graph_logy') = true; % do not log
    mp_support_graph('st_rowvar_name') = 'shock=';
    mp_support_graph('it_legend_select') = 5; % how many shock legends to show
    mp_support_graph('st_rounding') = '6.2f'; % format shock legend
    mp_support_graph('cl_colors') = 'jet'; % any predefined matlab colormap

    % Overide graph options here with external parameters
    if (length(varargin)>=3)
        mp_support_graph = [mp_support_graph; mp_support_graph_ext];
    end

    % summarize
    param_map_keys = keys(mp_ffgrh);
    param_map_vals = values(mp_ffgrh);
    for i = 1:length(mp_ffgrh)
        % Get matrix and key
        st_mt_name = param_map_keys{i};
        mt_cur = param_map_vals{i};

        % Update Title and Y label
        mp_support_graph('cl_st_graph_title') = {[st_mt_name '(a,z), savings state =x, shock state = color']};
        mp_support_graph('cl_st_ytitle') = {[st_mt_name '(a,z)']};

        % Call function
        ff_graph_grid(mt_cur', ar_z, ar_a, mp_support_graph);
    end

end

%% Store Results for Output
mp_valpol_out = containers.Map(ls_slout, values(mp_print_graph, ls_slout));

end

% Utility given choices
function [mt_val_smz, mt_aprime_smp, mt_c_smp] = ffi_vec_u_v_ap(...
    ar_aprime_frac, ar_a, ...
    ar_resources_amz, ar_z_ctr_amz_smz, mt_ev_ap_z, mt_deri_dev_dap, ...
    f_util, f_U)
% A. Percentage Asset Choice to Level Asset Choices
mt_aprime_smp = ar_aprime_frac.*(ar_resources_amz);
% smp states mesh percentages
ar_aprime_smp = mt_aprime_smp(:);

% B. Identify the Closest ar_a point to fl_aprime, this is spline knot point
ar_it_ap_near_lower_idx = sum(ar_a <= ar_aprime_smp, 2);
ar_it_ap_near_lower_idx(ar_it_ap_near_lower_idx == length(ar_a)) = length(ar_a) - 1;

% C. Current consumption
mt_c_smp = ar_resources_amz - mt_aprime_smp;

% D. Evaluate Value
mt_u_of_ap = f_util(mt_c_smp);

% the marginal effects of additional asset is determined by the slope
ar_deri_lin_idx = sub2ind(size(mt_deri_dev_dap), ar_it_ap_near_lower_idx, ar_z_ctr_amz_smz);
ar_ev_lin_idx = sub2ind(size(mt_ev_ap_z), ar_it_ap_near_lower_idx, ar_z_ctr_amz_smz);
ar_deri_dev_dap = mt_deri_dev_dap(ar_deri_lin_idx);
ar_ev_ap_lower_idx = mt_ev_ap_z(ar_ev_lin_idx);

% Ev(a_lower_idx,z) + slope*(fl_aprime - fl_a_lower)
ar_ev_aprime_z = ar_ev_ap_lower_idx + (ar_aprime_smp - ar_a(ar_it_ap_near_lower_idx)').*ar_deri_dev_dap;
mt_ev_aprime_z = reshape(ar_ev_aprime_z, size(mt_u_of_ap));

% overall utility at choice
mt_val_smz = f_U(mt_u_of_ap, mt_ev_aprime_z);
end
