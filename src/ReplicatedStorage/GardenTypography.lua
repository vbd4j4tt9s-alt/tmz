local M={}
function M.Apply(root)
 local function style(x)
  if x:IsA('TextLabel')or x:IsA('TextButton')or x:IsA('TextBox')then x.Font=Enum.Font.FredokaOne end
 end
 style(root);for _,x in ipairs(root:GetDescendants())do style(x)end
 return root.DescendantAdded:Connect(style)
end
return M
